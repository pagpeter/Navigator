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
import 'package:geocoding/geocoding.dart' as geo;

class ConnectionsPageAndroid extends StatefulWidget {
  final ConnectionsPage page;
  final Location to;

  const ConnectionsPageAndroid(this.page, this.to, {super.key});

  @override
  State<ConnectionsPageAndroid> createState() => _ConnectionsPageAndroidState();
}

class _ConnectionsPageAndroidState extends State<ConnectionsPageAndroid> {
  late final TextEditingController _toController;
  late final TextEditingController _fromController;
  late final GeoService geoService;
  late final ServicesMiddle services;
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

  @override
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
    services = ServicesMiddle();
    _getCurrentLocation();
    hasJourneys = _currentJourneys.isNotEmpty;

    _toController.addListener(() {
      _onSearchChanged(_toController.text.trim(), false);
    });
    _fromController.addListener(() {
      _onSearchChanged(_fromController.text.trim(), true);
    });
  }

  @override
  void dispose() {
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _toController.dispose();
    _fromController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, bool from) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query != _lastSearchedText) {
        getSearchResults(query, from);
        _lastSearchedText = query;
      }
    });
  }

  Future<void> getSearchResults(String query, bool from) async {
    final results = await getLocations(query);
    if (from) {
      setState(() {
        _searchResultsFrom = results;
      });
    } else {
      setState(() {
        _searchResultsTo = results;
      });
    }
  }

  Future<List<Location>> getLocations(String query) async {
    return await services.getLocations(query);
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
            children: [
              // Input card
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
                            _fromController,
                            _fromFocusNode,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            context,
                            Icons.location_on,
                            "To",
                            _toController,
                            _toFocusNode,
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        top: 32,
                        child: FloatingActionButton.small(
                          onPressed: swap,
                          child: const Icon(Icons.swap_vert),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              //Quick Options
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.departure_board),
                          label: Text(_selectedTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: _selectedDate,
                              helpText: 'Select Departure Date',
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton.filledTonal(
                          onPressed: () => {},
                          icon: const Icon(Icons.settings),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SegmentedButton<bool>(
                          segments: const <ButtonSegment<bool>>[
                            ButtonSegment<bool>(
                                value: true, label: Text('Departure')),
                            ButtonSegment<bool>(
                                value: false, label: Text('Arrival'))
                          ],
                          selected: {departure},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              departure = newSelection.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: FilledButton.tonalIcon(
                          onPressed: _fetchJourneysFromCurrentLocation,
                          label: const Text('Search'),
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Content area
              if (_searchResultsFrom.isNotEmpty)
                Expanded(child: _buildSearchScreen(_fromController, true))
              else if (_searchResultsTo.isNotEmpty)
                Expanded(child: _buildSearchScreen(_toController, false))
              else
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
      return const Center(child: CircularProgressIndicator());
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
                child: Card(
                  color: colorScheme.tertiaryContainer,
                  child: InkWell(
                    onTap: () => {},
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              flex: 2,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  "assets/Images/image.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              flex: 3,
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                  const Divider(
                                    thickness: 5,
                                    color: Colors.red,
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
      TextEditingController controller, [
        FocusNode? focusNode,
      ]) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) {},
      style: TextStyle(color: colors.onSurface),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIcon: Icon(icon, color: colors.primary),
        filled: true,
        fillColor: colors.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

      // Update the from controller with the current location address
      await _updateControllerWithLocation();

      await _fetchJourneysFromCurrentLocation();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get Location. Error: $err')),
        );
      }
    }
  }

  Future<void> _updateControllerWithLocation() async {
    if (_selectedPosition != null) {
      try {
        final placemarks = await geo.placemarkFromCoordinates(
            _selectedPosition!.latitude,
            _selectedPosition!.longitude
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final city = placemark.locality ?? '';
          final street = placemark.street ?? '';
          final address = _buildAddressString(city, street);

          _fromController.text = address.isNotEmpty ? address : 'Current Location';
        } else {
          _fromController.text = 'Current Location';
        }
      } catch (e) {
        print('Failed to get address for current location: $e');
        _fromController.text = 'Current Location';
      }
    }
  }

  String _buildAddressString(String city, String street) {
    final safeCity = city.trim();
    final safeStreet = street.trim();

    if (safeCity.isNotEmpty && safeStreet.isNotEmpty) {
      return '$safeCity, $safeStreet';
    } else if (safeCity.isNotEmpty) {
      return safeCity;
    } else if (safeStreet.isNotEmpty) {
      return safeStreet;
    } else {
      return '';
    }
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
    String? fromAddress;
    if (fromId.isEmpty) {
      try {
        final placemarks = await geo.placemarkFromCoordinates(fromLat, fromLon);
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final city = placemark.locality ?? '';
          final street = placemark.street ?? '';
          fromAddress = _buildAddressString(city, street);
        }
      } catch (e) {
        print('Failed to get address for from coordinates: $e');
        fromAddress = null;
      }
    }

    String? toAddress;
    if (toId.isEmpty) {
      try {
        final placemarks = await geo.placemarkFromCoordinates(toLat, toLong);
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final city = placemark.locality ?? '';
          final street = placemark.street ?? '';
          toAddress = _buildAddressString(city, street);
        }
      } catch (e) {
        print('Failed to get address for to coordinates: $e');
        toAddress = null;
      }
    }

    // Rest of the method remains the same...
    final from = fromId.isEmpty
        ? Location(
      id: '',
      latitude: fromLat,
      longitude: fromLon,
      name: "Current Location",
      type: "geo",
      address: fromAddress,
    )
        : Location(
      id: fromId,
      latitude: 0,
      longitude: 0,
      name: "",
      type: "",
      address: null,
    );

    final to = toId.isEmpty
        ? Location(
      id: '',
      latitude: toLat,
      longitude: toLong,
      name: widget.to.name,
      type: widget.to.type,
      address: toAddress,
    )
        : Location(
      id: toId,
      latitude: toLat,
      longitude: toLong,
      name: widget.to.name,
      type: widget.to.type,
      address: null,
    );

    final journeys = await services.getJourneys(
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

    String? fromAddress;
    try {
      final placemarks = await geo.placemarkFromCoordinates(
          _selectedPosition!.latitude, _selectedPosition!.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = placemark.locality ?? '';
        final street = placemark.street ?? '';
        fromAddress = _buildAddressString(city, street);
      }
    } catch (e) {
      print('Failed to get address for current location: $e');
      fromAddress = null;
    }

    final from = Location(
      id: '',
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
      name: 'Current Location',
      type: 'geo',
      address: fromAddress,
    );

    final to = Location(
      id: widget.to.id,
      latitude: widget.to.latitude,
      longitude: widget.to.longitude,
      name: widget.to.name,
      type: widget.to.type,
      address: null,
    );

    final journeys = await services.getJourneys(
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

  Widget _buildSearchScreen(TextEditingController t, bool from) {
    final searchResults = from ? _searchResultsFrom : _searchResultsTo;

    return SafeArea(
      child: ListView.builder(
        key: const ValueKey('list'),
        padding: const EdgeInsets.all(8),
        itemCount: searchResults.length,
        itemBuilder: (context, i) {
          final r = searchResults[i];
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
              builder: (_) => ConnectionsPageAndroid(ConnectionsPage(), station),
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
              builder: (_) => ConnectionsPageAndroid(ConnectionsPage(), location),
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
                child: Icon(
                  Icons.house,
                  size: 24,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  location.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}