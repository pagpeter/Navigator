import 'dart:async';

import 'package:flutter/material.dart';
import 'package:navigator/models/dateAndTime.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/models/station.dart';
import 'package:navigator/pages/page_models/connections_page.dart';
import 'package:navigator/pages/page_models/home_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navigator/services/geoLocator.dart';
import 'package:navigator/services/servicesMiddle.dart';
import 'package:navigator/models/journey.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ConnectionsPageAndroid extends StatefulWidget {
  ConnectionsPageAndroid(this.page, this.to, {super.key});

  ConnectionsPage page;
  Location to;
  ServicesMiddle services = ServicesMiddle();

  State<ConnectionsPageAndroid> createState() => _ConnectionsPageAndroidState();
}

class _ConnectionsPageAndroidState extends State<ConnectionsPageAndroid> {
  late final TextEditingController _toController;
  late final TextEditingController _fromController;
  late final GeoService geoService;
  late TimeOfDay _selectedTime;
  late DateTime _selectedDate;
  Position? _selectedPosition;
  List<Journey> _currentJourneys = [];
  bool hasJourneys = false;
  List<Location> _searchResultsFrom = [];
  List<Location> _searchResultsTo = [];
  String _lastSearchedText = '';
  Timer? _debounce;
  late FocusNode _fromFocusNode;
  late FocusNode _toFocusNode;
  bool departure = true;

  void initState() {
    super.initState();

    _fromFocusNode = FocusNode();
  _toFocusNode = FocusNode();

  _fromFocusNode.addListener(() {
    if (!_fromFocusNode.hasFocus) {
      // Clear "from" search results when focus is lost
      setState(() {
        _searchResultsFrom.clear();
      });
    }
  });

  _toFocusNode.addListener(() {
    if (!_toFocusNode.hasFocus) {
      // Clear "to" search results when focus is lost
      setState(() {
        _searchResultsTo.clear();
      });
    }
  });

    _toController = TextEditingController(text: widget.to.name);
    _fromController = TextEditingController();
    _selectedTime = TimeOfDay.now();
    _selectedDate = DateTime.now();
    geoService = GeoService();
    _getCurrentLocation();
    hasJourneys = _currentJourneys.isNotEmpty;
    _toController.addListener(() {
      _onSearchChanged(_toController.text.trim(), false);
    });
    _fromController.addListener(() {
      _onSearchChanged(_fromController.text.trim(), true);
    });
  }

  void dispose() {
    super.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
  _toController.dispose();
  _fromController.dispose();
  _debounce?.cancel();
  super.dispose();
  }

  void _onSearchChanged(String query, bool from) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query != _lastSearchedText) {
        getSearchResults(query, from);
        _lastSearchedText = query;
      }
    });
  }

  Future<void> getSearchResults(String query, bool from) async {
    final results = await getLocations(query); // async method
    if(from)
    {
      setState(() {
      _searchResultsFrom = results;
    });
    }
    else
    {
      setState(() {
      _searchResultsTo = results;
    });
    }
    
  }

  Future<List<Location>> getLocations(String query) async {
    return await widget.services.getLocations(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 16,
            children: [
              // ——— M3 expressive “card” for inputs ———
              Card(
                color: colors.surfaceVariant,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _buildInputField(
                            context,
                            Icons.radio_button_checked,
                            'From',
                            _updateControllerWithLocation(_fromController),
                            _fromFocusNode
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            context,
                            Icons.location_on,
                            "To",
                            _toController,
                            _toFocusNode
                          ),
                        ],
                      ),

                      // M3 small FAB, no overrides—theme provides size, shape & color
                      Positioned(
                        right: 0,
                        top: 32, // centers between the two 56dp-high fields
                        child: FloatingActionButton.small(
                          onPressed: swap,
                          child: const Icon(Icons.swap_vert),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              //Quick Options
              Column(
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.departure_board),
                          label: Text(_selectedTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime ?? TimeOfDay.now(),
                              helpText: 'Select departure time',
                            );
                            if (time != null) {
                              setState(() {
                                _selectedTime = time;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.calendar_month),
                          label: Text(
                            _selectedDate.day.toString() +
                                '.' +
                                _selectedDate.month.toString() +
                                '.' +
                                _selectedDate.year.toString(),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: _selectedDate ?? DateTime.now(),
                              helpText: 'Select Departure Text',
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton.filledTonal(
                          onPressed: () => {},
                          icon: Icon(Icons.settings),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SegmentedButton<bool>
                        (
                          segments: const <ButtonSegment<bool>>[
                            ButtonSegment<bool>(value: true, label: Text('Departure')),
                            ButtonSegment<bool>(value: false, label: Text('Arrival'))
                          ],
                          selected: {departure},
                          onSelectionChanged: (Set<bool> newSelection)
                          {
                            setState(() {
                              departure = newSelection.first;
                            });
                          },
                        ),
                      ),
                      Expanded(flex: 1, child: FilledButton.tonalIcon(onPressed: _fetchJourneysFromCurrentLocation, label: Text('Search'), icon: Icon(Icons.search)))
                  ],)
                ],
              ),
              // Jorneys
              if(_searchResultsFrom.isNotEmpty)
              Expanded(child: _buildSearchScreen(_fromController, true)),
              if(_searchResultsTo.isNotEmpty)
              Expanded(child: _buildSearchScreen(_toController, false)),
              if(_searchResultsFrom.isEmpty && _searchResultsTo.isEmpty)
              Expanded(child: _buildJourneys(context)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }

  Widget _buildJourneys(BuildContext context) {
    if (!hasJourneys) {
      //loading indicator
      return CircularProgressIndicator();
    } else {
      TextTheme textTheme = Theme.of(context).textTheme;
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      return Card.filled(
        color: colorScheme.tertiaryContainer.withAlpha(120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: ListView.builder(
            key: const ValueKey('list'),
            itemCount: _currentJourneys.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  //spacing: 8,
                  children: [
                    Card(
                      color: colorScheme.tertiaryContainer,
                      child: InkWell(
                        onTap: () => {},
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          // IntrinsicHeight makes the Row take on the tallest child's height,
                          // and with crossAxisAlignment.stretch each child will fill that height.
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1) The image fills the full height (minus padding), flexed
                                Flexible(
                                  flex:
                                      2, // adjust this to give the image more or less width
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      "assets/Images/image.png",
                                      fit: BoxFit
                                          .cover, // covers the full height
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // 2) The text + divider in a flexed column
                                Flexible(
                                  flex:
                                      3, // gives this side more room than the image
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // your two info columns side by side
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'In 20 minutes',
                                                style: textTheme.titleMedium,
                                              ),
                                              Text(
                                                'Departure 14:02',
                                                style: textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                '45',
                                                style: textTheme.titleMedium,
                                              ),
                                              Text(
                                                'minutes',
                                                style: textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // divider only under the text area
                                      const Divider(
                                        thickness: 5,
                                        color: Colors.red,
                                        // no indent/endIndent so it spans full text width
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildInputField(
  BuildContext context,
  IconData icon,
  String hintText,
  TextEditingController controller,
  [FocusNode? focusNode]
) {
  final colors = Theme.of(context).colorScheme;
  return TextField(
    controller: controller,
    focusNode: focusNode,
    onChanged: (_) {}, // your debounce logic upstream
    style: TextStyle(color: colors.onSurface),
    cursorColor: colors.primary,
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      prefixIcon: Icon(icon, color: colors.primary),
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}


  void swap() {
    String temp = _toController.text;
    _toController.text = _fromController.text;
    _fromController.text = temp;
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await geoService.determinePosition();
      setState(() {
        _selectedPosition = pos;
      });
      await _fetchJourneysFromCurrentLocation(); // <-- auto-fetch after location
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get Location. Error: $err')),
      );
    }
  }

  TextEditingController _updateControllerWithLocation(TextEditingController c) {
    if (_selectedPosition != null) {
      c.text = _selectedPosition!.latitude.toString();
    }
    return c;
  }

  Future<void> getJourneys(
    String fromId,
    String toId,
    double fromLat,
    double fromLon,
    double toLat,
    double toLong,
    DateAndTime when,
    bool departure,
  ) async {
    final from = fromId.isEmpty
        ? Location(
            id: "0",
            latitude: fromLat,
            longitude: fromLon,
            name: "Current Location",
            type: "geo",
          )
        : Location(id: fromId, latitude: 0, longitude: 0, name: "", type: "");

    final to = Location(
      id: toId,
      latitude: toLat,
      longitude: toLong,
      name: widget.to.name,
      type: widget.to.type,
    );

    final journeys = await widget.services.getJourneys(
      from,
      to,
      when,
      departure,
    );

    setState(() {
      _currentJourneys = journeys;
      hasJourneys = journeys.isNotEmpty;
    });
  }

  Future<void> _fetchJourneysFromCurrentLocation() async {
    if (_selectedPosition == null) return;

    final now = DateTime.now();
    final tzOffset = now.timeZoneOffset;

    final when = DateAndTime(
      day: _selectedDate.day,
      month: _selectedDate.month,
      year: _selectedDate.year,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      timeZoneHourShift: tzOffset.inHours,
      timeZoneMinuteShift: tzOffset.inMinutes % 60,
    );

    await getJourneys(
      '', // fromId empty = use coordinates
      widget.to.id,
      //selectedPosition!.latitude
      54.374348,
      9.101344,
      //_selectedPosition!.longitude,
      widget.to.latitude,
      widget.to.longitude,
      when,
      true,
    );
  }

  Widget _buildSearchScreen(TextEditingController t, bool from) {
    if(from)
    {
      return SafeArea(
      child: ListView.builder(
        key: const ValueKey('list'),
        padding: const EdgeInsets.all(8),
        itemCount: _searchResultsFrom.length,
        itemBuilder: (context, i) {
          final r = _searchResultsFrom[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: r is Station
                ? _stationResult(context, r)
                : _locationResult(context, r),
          );
        },
      ),
    );
    }
    else
    {
      return SafeArea(
      child: ListView.builder(
        key: const ValueKey('list'),
        padding: const EdgeInsets.all(8),
        itemCount: _searchResultsTo.length,
        itemBuilder: (context, i) {
          final r = _searchResultsTo[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: r is Station
                ? _stationResult(context, r)
                : _locationResult(context, r),
          );
        },
      ),
    );
    }
    
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
              builder: (_) =>
                  ConnectionsPageAndroid(ConnectionsPage(), station),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Tonal avatar for the station icon
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

              // Station name + service icons
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
                          Icon(
                            Icons.directions_railway,
                            size: 20,
                            color: colors.tertiary,
                          ),
                        if (station.regional)
                          Icon(
                            Icons.directions_transit,
                            size: 20,
                            color: colors.tertiary,
                          ),
                        if (station.suburban)
                          Icon(
                            Icons.directions_subway,
                            size: 20,
                            color: colors.tertiary,
                          ),
                        if (station.bus)
                          Icon(
                            Icons.directions_bus,
                            size: 20,
                            color: colors.tertiary,
                          ),
                        if (station.ferry)
                          Icon(
                            Icons.directions_ferry,
                            size: 20,
                            color: colors.tertiary,
                          ),
                        if (station.subway)
                          Icon(Icons.subway, size: 20, color: colors.tertiary),
                        if (station.tram)
                          Icon(Icons.tram, size: 20, color: colors.tertiary),
                        if (station.taxi)
                          Icon(
                            Icons.local_taxi,
                            size: 20,
                            color: colors.tertiary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Trailing chevron
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
              builder: (_) =>
                  ConnectionsPageAndroid(ConnectionsPage(), location),
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
