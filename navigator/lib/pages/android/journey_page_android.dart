import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/leg.dart';
import 'package:navigator/pages/page_models/journey_page.dart';

class JourneyPageAndroid extends StatefulWidget {
  final JourneyPage page;
  final Journey journey;

  const JourneyPageAndroid(
      this.page, {
        Key? key,
        required this.journey,
      }) : super(key: key);

  @override
  State<JourneyPageAndroid> createState() => _JourneyPageAndroidState();
}

class _JourneyPageAndroidState extends State<JourneyPageAndroid>
    with SingleTickerProviderStateMixin {
  // Sheet controller for the draggable bottom sheet
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  // Sheet size constants
  static const double _minChildSize = 0.1;
  static const double _maxChildSize = 1.0;
  static const double _initialChildSize = 0.6;

  // Map-related variables
  LatLng? _currentUserLocation;
  LatLng _currentCenter = const LatLng(52.513416, 13.412364); // Berlin default
  double _currentZoom = 10;
  final MapController _mapController = MapController();

  // Location tracking variables
  late StreamController<LocationMarkerPosition> _locationStreamController;
  late StreamController<LocationMarkerHeading> _headingStreamController;
  StreamSubscription<Position>? _geolocatorSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
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

  void _initializeLocationTracking() {
    _locationStreamController = StreamController<LocationMarkerPosition>();
    _headingStreamController = StreamController<LocationMarkerHeading>();

    // Note: A production app should handle location permissions.
    _geolocatorSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      final locationMarkerPosition = LocationMarkerPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      final locationMarkerHeading = LocationMarkerHeading(
        heading: position.heading * math.pi / 180,
        accuracy: position.headingAccuracy * math.pi / 180,
      );

      _handleLocationUpdate(locationMarkerPosition);

      if (!_locationStreamController.isClosed) {
        _locationStreamController.add(locationMarkerPosition);
      }
      if (!_headingStreamController.isClosed) {
        _headingStreamController.add(locationMarkerHeading);
      }
    });
  }

  void _handleLocationUpdate(LocationMarkerPosition position) {
    setState(() {
      // First location update - center map on user
      if (_currentUserLocation == null) {
        _currentUserLocation = position.latLng;
        // Use animatedMapMove instead of direct move for smoother experience
        animatedMapMove(_currentUserLocation!, 15.0);
        _currentCenter = _currentUserLocation!;
        _currentZoom = 15.0;
      } else {
        _currentUserLocation = position.latLng;
      }
    });
  }

  @override
  void dispose() {
    // Clean up the stream controllers and subscription
    _locationStreamController.close();
    _headingStreamController.close();
    _geolocatorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMapView(context),
          _buildDraggableSheet(context),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildDraggableSheet(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialChildSize,
      minChildSize: _minChildSize,
      maxChildSize: _maxChildSize,
      snap: true,
      snapSizes: const [0.1, 0.4, 0.6, 1],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSheetHandle(context),
              Expanded(
                child: _buildJourneyContent(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (details) {
            final fractionDelta =
                details.primaryDelta! / MediaQuery.of(context).size.height;
            final newSize = (_sheetController.size - fractionDelta)
                .clamp(_minChildSize, _maxChildSize);
            _sheetController.jumpTo(newSize);
          },
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildJourneyContent(
      BuildContext context, ScrollController scrollController) {
    final journey = widget.journey;

    if (journey.legs.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: journey.legs.length,
      itemBuilder: (context, index) {
        final leg = journey.legs[index];
        final isLast = index == journey.legs.length - 1;

        return Column(
          children: [
            _buildLegCard(context, leg, index, journey.legs),
            if (!isLast) _buildConnectionLine(context),
          ],
        );
      },
    );
  }

  Widget _buildLegCard(
      BuildContext context, Leg leg, int index, List<Leg> legs) {
    // Skip walking legs with zero or null distance
    if (leg.isWalking == true && (leg.distance == null || leg.distance == 0)) {
      return const SizedBox.shrink();
    }

    final platformChangeText = _getPlatformChangeText(leg, index, legs);
    final hasDelay = leg.hasDelays;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _buildLegHeader(context, leg, platformChangeText, hasDelay),
          const SizedBox(height: 16),
          _buildLegDetails(context, leg),
        ],
      ),
    );
  }

  String? _getPlatformChangeText(Leg leg, int index, List<Leg> legs) {
    if (leg.isWalking != true || index <= 0 || index >= legs.length - 1) {
      return null;
    }

    final prevLeg = legs[index - 1];
    final nextLeg = legs[index + 1];

    if (prevLeg.arrivalPlatformEffective.isNotEmpty &&
        nextLeg.departurePlatformEffective.isNotEmpty &&
        prevLeg.arrivalPlatformEffective !=
            nextLeg.departurePlatformEffective) {
      return 'Platform change: ${prevLeg.arrivalPlatformEffective} to ${nextLeg.departurePlatformEffective}';
    }
    return null;
  }

  Widget _buildLegHeader(
      BuildContext context, Leg leg, String? platformChangeText, bool hasDelay) {
    return Row(
      children: [
        _buildLegIcon(context, leg),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLegTitle(context, leg, platformChangeText),
        ),
        if (hasDelay && leg.isWalking != true) _buildDelayChip(context, leg),
      ],
    );
  }

  Widget _buildLegIcon(BuildContext context, Leg leg) {
    if (leg.isWalking == true) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.directions_walk,
          size: 20,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        leg.lineName ?? 'Transit',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLegTitle(
      BuildContext context, Leg leg, String? platformChangeText) {
    if (leg.isWalking == true && platformChangeText != null) {
      return _buildPlatformChangeText(context, platformChangeText);
    }

    if (leg.direction != null && leg.direction!.isNotEmpty) {
      return Text(
        leg.direction!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlatformChangeText(
      BuildContext context, String platformChangeText) {
    final parts = platformChangeText.split(' to ');
    if (parts.length != 2) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          parts[0], // Keep the "Platform change: X" text intact
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.orange,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 14, color: Colors.orange),
        ),
        Flexible(
          child: Text(
            parts[1],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDelayChip(BuildContext context, Leg leg) {
    final delayMinutes =
        leg.departureDelayMinutes ?? leg.arrivalDelayMinutes ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 12,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '+${delayMinutes}min',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegDetails(BuildContext context, Leg leg) {
    return Row(
      children: [
        Expanded(child: _buildDepartureInfo(context, leg)),
        const SizedBox(width: 12),
        _buildDurationChip(context, leg),
        const SizedBox(width: 12),
        Expanded(child: _buildArrivalInfo(context, leg)),
      ],
    );
  }

  Widget _buildDepartureInfo(BuildContext context, Leg leg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Departure',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leg.origin.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(leg.departureDateTime),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (leg.departurePlatformEffective.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Platform ${leg.departurePlatformEffective}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalInfo(BuildContext context, Leg leg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Arrival',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                leg.destination.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.end,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(leg.arrivalDateTime),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (leg.arrivalPlatformEffective.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Platform ${leg.arrivalPlatformEffective}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationChip(BuildContext context, Leg leg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        leg.isWalking == true
            ? (leg.distance != null && leg.distance! > 0
            ? '${leg.distance}m'
            : 'Same platform')
            : _formatLegDuration(leg.departureDateTime, leg.arrivalDateTime),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildConnectionLine(BuildContext context) {
    return Container(
      height: 24,
      width: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No journeys found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentUserLocation ?? _currentCenter,
        initialZoom: _currentZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
          InteractiveFlag.flingAnimation |
          InteractiveFlag.pinchZoom |
          InteractiveFlag.doubleTapZoom |
          InteractiveFlag.rotate,
          rotationThreshold: 20.0,
          pinchZoomThreshold: 0.5,
          pinchMoveThreshold: 40.0,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        CurrentLocationLayer(
          alignPositionOnUpdate: AlignOnUpdate.never,
          alignDirectionOnUpdate: AlignOnUpdate.never,
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
        _buildLocationButton(context),
      ],
    );
  }

  Widget _buildLocationButton(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0, bottom: 116.0),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          onPressed: _centerOnUserLocation,
          child: Icon(
            Icons.my_location,
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
      ],
    );
  }

  void _centerOnUserLocation() {
    if (_currentUserLocation != null) {
      // Use the existing animatedMapMove method for smooth transition
      animatedMapMove(_currentUserLocation!, 18.0);

      // Update the current center and zoom values
      _currentCenter = _currentUserLocation!;
      _currentZoom = 18.0;
    }
  }

  // Helper methods
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatLegDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '0min';

    final duration = end.difference(start);
    final minutes = (duration.inSeconds / 60).ceil();

    return minutes <= 0 ? '1min' : '${minutes}min';
  }
}