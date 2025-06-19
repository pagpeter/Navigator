import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/pages/android/connections_page_android.dart';
import 'package:navigator/pages/page_models/connections_page.dart';
import 'package:navigator/pages/page_models/home_page.dart';
import 'package:navigator/models/station.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:navigator/services/BakedTiles/tileProvider.dart';
import 'package:navigator/services/BakedTiles/batchTileRenderer.dart';
import 'package:path_provider/path_provider.dart';

class HomePageAndroid extends StatefulWidget {
  final HomePage page;
  final bool ongoingJourney;

  const HomePageAndroid(this.page, this.ongoingJourney, {Key? key})
    : super(key: key);

  @override
  State<HomePageAndroid> createState() => _HomePageAndroidState();
}

class _HomePageAndroidState extends State<HomePageAndroid>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<Location> _searchResults = [];
  String _lastSearchedText = '';
  Timer? _debounce;
  LatLng? _currentUserLocation;
  LatLng _currentCenter = LatLng(52.513416, 13.412364);
  double _currentZoom = 10;
  final MapController _mapController = MapController();
  List<Polyline> _lines = [];

  //Map Options
  bool showLightRail = true;
  List<Polyline> _lightRailLines = [];
  bool showSubway = true;
  List<Polyline> _subwayLines = [];
  bool showTram = false;
  List<Polyline> _tramLines = [];
  bool showFerry = false;
  List<Polyline> _ferryLines = [];
  bool showFunicular = false;
  List<Polyline> _funicularLines = [];
  late AlignOnUpdate _alignPositionOnUpdate;
  late final StreamController<double?> _alignPositionStreamController;

  // Tile rendering system
  SubwayTileLayer? _subwayTileLayer;
  bool _tilesReady = false;
  bool _tilesGenerating = false;
  double _tileGenerationProgress = 0.0;
  String? _cacheDir;
  Timer? _tileCheckTimer;

  @override
  void initState() {
    super.initState();
    initiateLines();
    _initializeTileSystem();

    _alignPositionOnUpdate = AlignOnUpdate.always;
    _alignPositionStreamController = StreamController<double?>();

    _controller.addListener(() {
      _onSearchChanged(_controller.text.trim());
    });

    _setInitialUserLocation();
  }

  Future<void> _initializeTileSystem() async {
    try {
      // Get cache directory
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = '${appDir.path}/subway_tiles';
      
      // Create cache directory if it doesn't exist
      final cacheDirectory = Directory(_cacheDir!);
      if (!cacheDirectory.existsSync()) {
        cacheDirectory.createSync(recursive: true);
      }

      // Check if tiles already exist
      _checkExistingTiles();
      
      // Start background tile generation if needed
      _startBackgroundTileGeneration();
      
    } catch (e) {
      print('Error initializing tile system: $e');
    }
  }

  void _checkExistingTiles() {
    if (_cacheDir == null) return;
    
    final batchRenderer = BatchTileRenderer();
    final stats = batchRenderer.getCacheStats(_cacheDir!);
    
    if (stats['totalTiles'] > 0) {
      print('Found ${stats['totalTiles']} cached tiles (${stats['totalSizeMB']} MB)');
      _setupTileLayer();
    } else {
      print('No cached tiles found, will generate in background');
    }
  }

  void _setupTileLayer() {
    if (_cacheDir == null) return;
    
    setState(() {
      _subwayTileLayer = SubwayTileLayer.cacheOnly(cacheDir: _cacheDir!);
      _tilesReady = true;
    });
  }

  Future<void> _startBackgroundTileGeneration() async {
    if (_tilesReady || _tilesGenerating || widget.page.service.loadedSubwayLines.isEmpty) {
      return;
    }

    setState(() {
      _tilesGenerating = true;
      _tileGenerationProgress = 0.0;
    });

    try {
      final batchRenderer = BatchTileRenderer();
      
      // Generate tiles for zoom levels 10-16 (adjust as needed)
      final zoomLevels = [10, 11, 12, 13, 14, 15, 16];
      
      await batchRenderer.renderMultipleZoomLevels(
        subwayLines: widget.page.service.loadedSubwayLines,
        zoomLevels: zoomLevels,
        outputDir: _cacheDir!,
        onProgress: (currentZoom, totalZooms, currentTile, totalTiles) {
          final zoomProgress = (currentZoom - 1) / totalZooms;
          final tileProgressInZoom = currentTile / totalTiles / totalZooms;
          final overallProgress = zoomProgress + tileProgressInZoom;
          
          setState(() {
            _tileGenerationProgress = overallProgress;
          });
          
          print('Generating tiles: Zoom $currentZoom/$totalZooms, Tile $currentTile/$totalTiles (${(overallProgress * 100).toStringAsFixed(1)}%)');
        },
      );

      // Setup tile layer once generation is complete
      _setupTileLayer();
      
      setState(() {
        _tilesGenerating = false;
        _tileGenerationProgress = 1.0;
      });
      
      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subway tiles generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      print('Error generating tiles: $e');
      setState(() {
        _tilesGenerating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating subway tiles'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> initiateLines() async {
    await widget.page.service.refreshPolylines();

    print(
      "loadedSubwayLines.length = ${widget.page.service.loadedSubwayLines.length}",
    );

    if (widget.page.service.loadedSubwayLines.isNotEmpty) {
      setState(() {
        _lines = widget.page.service.loadedSubwayLines
            .where((subwayLine) => subwayLine.points.isNotEmpty)
            .map((subwayLine) => Polyline(
                points: subwayLine.points,
                strokeWidth: 2.0,
                color: subwayLine.color,
                borderColor: subwayLine.color.withAlpha(60)))
            .toList();
            
        _subwayLines = widget.page.service.loadedSubwayLines
            .where((subwayLine) => subwayLine.points.isNotEmpty && subwayLine.type == 'subway')
            .map((subwayLine) => Polyline(
                points: subwayLine.points,
                strokeWidth: 2.0,
                color: subwayLine.color,
                borderColor: subwayLine.color.withAlpha(60)))
            .toList();
            
        _lightRailLines = widget.page.service.loadedSubwayLines
            .where((subwayLine) => subwayLine.points.isNotEmpty && subwayLine.type == 'light_rail')
            .map((subwayLine) => Polyline(
                points: subwayLine.points,
                strokeWidth: 2.0,
                color: subwayLine.color,
                borderColor: subwayLine.color.withAlpha(60)))
            .toList();
            
        _tramLines = widget.page.service.loadedSubwayLines
            .where((subwayLine) => subwayLine.points.isNotEmpty && subwayLine.type == 'tram')
            .map((subwayLine) => Polyline(
                points: subwayLine.points,
                strokeWidth: 2.0,
                color: subwayLine.color,
                borderColor: subwayLine.color.withAlpha(60)))
            .toList();
            
        _ferryLines = widget.page.service.loadedSubwayLines
            .where((subwayLine) => subwayLine.points.isNotEmpty && subwayLine.type == 'ferry')
            .map((subwayLine) => Polyline(
                points: subwayLine.points,
                strokeWidth: 1.0,
                color: subwayLine.color,
                borderColor: subwayLine.color.withAlpha(60)))
            .toList();
            
        _funicularLines = widget.page.service.loadedSubwayLines
            .where((subwayLine) => subwayLine.points.isNotEmpty && subwayLine.type == 'funicular')
            .map((subwayLine) => Polyline(
                points: subwayLine.points,
                strokeWidth: 2.0,
                color: subwayLine.color,
                borderColor: subwayLine.color.withAlpha(60)))
            .toList();
      });

      print("Mapped ${_lines.length} colored polylines for display.");
    }
  }

  void animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _currentCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _currentCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: _currentZoom, end: destZoom);

    var controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _setInitialUserLocation() async {
    final loc = await widget.page.service.getCurrentLocation();

    if (loc.latitude != 0 && loc.longitude != 0) {
      final newCenter = LatLng(loc.latitude, loc.longitude);
      setState(() {
        _currentUserLocation = newCenter;
      });

      animatedMapMove(newCenter, 12.0);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query != _lastSearchedText) {
        getSearchResults(query);
        _lastSearchedText = query;
      }
    });
  }

  Future<void> getSearchResults(String query) async {
    final results = await widget.page.getLocations(query);
    setState(() {
      _searchResults = results;
    });
  }

  Future<void> _regenerateTiles() async {
    if (_cacheDir == null) return;
    
    // Clear existing cache
    final batchRenderer = BatchTileRenderer();
    batchRenderer.clearCache(outputDir: _cacheDir!);
    
    setState(() {
      _tilesReady = false;
      _subwayTileLayer = null;
    });
    
    // Start regeneration
    _startBackgroundTileGeneration();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tileCheckTimer?.cancel();
    _controller.dispose();
    _alignPositionStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasResults = _searchResults.isNotEmpty;
    const bottomSheetHeight = 96.0;

    return WillPopScope(
      onWillPop: () async {
        if (hasResults) {
          setState(() {
            _searchResults.clear();
            _lastSearchedText = '';
            _controller.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: colors.surfaceContainerHighest,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero
                ).animate(anim);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              child: hasResults
                  ? SafeArea(
                      child: ListView.builder(
                        key: const ValueKey('list'),
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          bottomSheetHeight + 16,
                        ),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final r = _searchResults[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: r is Station
                                ? _stationResult(context, r)
                                : _locationResult(context, r),
                          );
                        },
                      ),
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentUserLocation ?? _currentCenter,
                        initialZoom: _currentZoom,
                        minZoom: 3.0,
                        maxZoom: 18.0,
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.drag | 
                                 InteractiveFlag.flingAnimation | 
                                 InteractiveFlag.pinchZoom | 
                                 InteractiveFlag.doubleTapZoom | 
                                 InteractiveFlag.rotate,
                          rotationThreshold: 20.0,
                          pinchZoomThreshold: 0.5,
                          pinchMoveThreshold: 40.0,
                        ),
                        onPositionChanged: (MapCamera camera, bool hasGesture) {
                          if (hasGesture && _alignPositionOnUpdate != AlignOnUpdate.never) {
                            setState(() => _alignPositionOnUpdate = AlignOnUpdate.never);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                        ),
                        
                        // Use rendered tiles if ready, otherwise fall back to polylines
                        if (_tilesReady && _subwayTileLayer != null)
                          _subwayTileLayer!.getTileLayer()
                        else ...[
                          if (showSubway) PolylineLayer(polylines: _subwayLines),
                          if (showLightRail) PolylineLayer(polylines: _lightRailLines),
                          if (showTram) PolylineLayer(polylines: _tramLines),
                          if (showFerry) PolylineLayer(polylines: _ferryLines),
                          if (showFunicular) PolylineLayer(polylines: _funicularLines),
                        ],
                        
                        CurrentLocationLayer(
                          alignPositionStream: _alignPositionStreamController.stream,
                          alignPositionOnUpdate: _alignPositionOnUpdate,
                          style: LocationMarkerStyle(
                            marker: DefaultLocationMarker(
                              color: Colors.lightBlue[800]!,
                            ),
                            markerSize: const Size(20, 20),
                            markerDirection: MarkerDirection.heading,
                            accuracyCircleColor: Colors.blue[200]!.withAlpha(0x20),
                            headingSectorColor: Colors.blue[400]!.withAlpha(0x90),
                            headingSectorRadius: 60,
                          ),
                        ),
                        
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20.0, bottom: 116.0),
                            child: FloatingActionButton(
                              shape: const CircleBorder(),
                              onPressed: () {
                                setState(() => _alignPositionOnUpdate = AlignOnUpdate.always);
                                _alignPositionStreamController.add(18);
                              },
                              child: Icon(
                                Icons.my_location,
                                color: colors.tertiary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            
            // Tile generation progress indicator
            if (_tilesGenerating)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Generating subway tiles...'),
                          ],
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(value: _tileGenerationProgress),
                        SizedBox(height: 4),
                        Text('${(_tileGenerationProgress * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomSheet: Material(
          color: colors.surfaceContainer,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: colors.onPrimaryContainer),
                    decoration: InputDecoration(
                      hintText: 'Where do you want to go?',
                      prefixIcon: Icon(Icons.location_pin, color: colors.primary),
                      filled: true,
                      fillColor: colors.primaryContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _showMapOptionsBottomSheet(context),
                  icon: Icon(Icons.settings),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
          ],
        ),
      ),
    );
  }

  void _showMapOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Map Options',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Tile rendering status
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subway Tiles',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  SizedBox(height: 8),
                                  if (_tilesReady)
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                                        SizedBox(width: 8),
                                        Text('Tiles ready - Using high-performance rendering'),
                                      ],
                                    )
                                  else if (_tilesGenerating)
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Generating tiles... ${(_tileGenerationProgress * 100).toStringAsFixed(1)}%'),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Icon(Icons.warning, color: Colors.orange, size: 16),
                                        SizedBox(width: 8),
                                        Text('Using fallback rendering'),
                                      ],
                                    ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: _tilesGenerating ? null : _regenerateTiles,
                                        child: Text('Regenerate Tiles'),
                                      ),
                                      if (_cacheDir != null) ...[
                                        SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () {
                                            final stats = BatchTileRenderer().getCacheStats(_cacheDir!);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Cache: ${stats['totalTiles']} tiles, ${stats['totalSizeMB']} MB'
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text('Cache Info'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Transit type toggles (only shown when using fallback rendering)
                          if (!_tilesReady) ...[
                            Text(
                              'Transit Types',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            CheckboxListTile(
                              title: const Text('Show S-Bahn'),
                              value: showLightRail,
                              onChanged: (bool? value) {
                                setModalState(() => showLightRail = value!);
                                setState(() => showLightRail = value!);
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Show U-Bahn'),
                              value: showSubway,
                              onChanged: (bool? value) {
                                setModalState(() => showSubway = value!);
                                setState(() => showSubway = value!);
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Show Tram'),
                              value: showTram,
                              onChanged: (bool? value) {
                                setModalState(() => showTram = value!);
                                setState(() => showTram = value!);
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Show Ferry'),
                              value: showFerry,
                              onChanged: (bool? value) {
                                setModalState(() => showFerry = value!);
                                setState(() => showFerry = value!);
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Show Funicular'),
                              value: showFunicular,
                              onChanged: (bool? value) {
                                setModalState(() => showFunicular = value!);
                                setState(() => showFunicular = value!);
                              },
                            ),
                          ] else
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'All transit types are included in the rendered tiles.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _stationResult(BuildContext context, Station station) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.hardEdge,
      color: colors.surfaceContainerHighest,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConnectionsPageAndroid(
                ConnectionsPage(
                  from: Location(
                    id: '',
                    latitude: 0,
                    longitude: 0,
                    name: '',
                    type: '',
                  ),
                  to: station,
                  services: widget.page.service,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.tertiaryContainer,
                child: SvgPicture.asset(
                  "assets/Icon/Train_Station_Icon.svg",
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    colors.onTertiaryContainer,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (station.national || station.nationalExpress)
                          Icon(Icons.train, size: 20, color: colors.tertiary),
                        if (station.regionalExpress)
                          Icon(Icons.directions_railway, size: 20, color: colors.tertiary),
                        if (station.regional)
                          Icon(Icons.directions_transit, size: 20, color: colors.tertiary),
                        if (station.suburban)
                          Icon(Icons.directions_subway, size: 20, color: colors.tertiary),
                        if (station.bus)
                          Icon(Icons.directions_bus, size: 20, color: colors.tertiary),
                        if (station.ferry)
                          Icon(Icons.directions_ferry, size: 20, color: colors.tertiary),
                        if (station.subway)
                          Icon(Icons.subway, size: 20, color: colors.tertiary),
                        if (station.tram)
                          Icon(Icons.tram, size: 20, color: colors.tertiary),
                        if (station.taxi)
                          Icon(Icons.local_taxi, size: 20, color: colors.tertiary),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
  Widget _locationResult(BuildContext context, Location location) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.hardEdge,
      color: colors.surfaceContainerHighest,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConnectionsPageAndroid(
                ConnectionsPage(
                  from: Location(
                    id: '',
                    latitude: 0,
                    longitude: 0,
                    name: '',
                    type: '',
                  ),
                  to: location,
                  services: widget.page.service,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Tonal avatar for the “home” icon
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.tertiaryContainer,
                child: Icon(
                  Icons.house,
                  size: 24,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 16),

              // Location name
              Expanded(
                child: Text(
                  location.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),

              // Chevron affordance
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}