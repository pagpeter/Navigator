import 'dart:async';
import 'dart:math' as math;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/leg.dart';
import 'package:navigator/pages/page_models/journey_page.dart';
import 'dart:convert';
import 'package:navigator/models/station.dart';

import '../../services/overpassApi.dart';

class JourneyPageAndroid extends StatefulWidget {
  final JourneyPage page;
  final Journey journey;

  const JourneyPageAndroid(this.page, {Key? key, required this.journey})
    : super(key: key);

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
    _geolocatorSubscription =
        Geolocator.getPositionStream(
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
        children: [_buildMapView(context), _buildDraggableSheet(context)],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildDraggableSheet(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _initialChildSize,
        minChildSize: _minChildSize,
        maxChildSize: _maxChildSize,
        snap: true,
        snapSizes: const [0.1, 0.4, 0.6, 1],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
      ),
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
            final newSize = (_sheetController.size - fractionDelta).clamp(
              _minChildSize,
              _maxChildSize,
            );
            _sheetController.jumpTo(newSize);
          },
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildJourneyContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final journey = widget.journey;

    if (journey.legs.isEmpty) {
      return _buildEmptyState(context);
    }

    // Build components for actual travel legs (not same-station interchanges)
    List<Widget> journeyComponents = [];
    List<int> actualLegIndices = [];

    // First, identify which legs are actual travel vs same-station interchanges
    for (int index = 0; index < journey.legs.length; index++) {
      final leg = journey.legs[index];

      // Skip legs that are same-station interchanges (same origin and destination)
      bool isSameStationInterchange =
          leg.origin.id == leg.destination.id &&
          leg.origin.name == leg.destination.name;

      if (!isSameStationInterchange) {
        actualLegIndices.add(index);
      }
    }

    final List<String> previousRil100Ids = List.empty();
    // Build components for actual legs
    for (int i = 0; i < actualLegIndices.length; i++) {
      final legIndex = actualLegIndices[i];
      final leg = journey.legs[legIndex];
      final isFirst = i == 0;
      final isLast = i == actualLegIndices.length - 1;

      // Add origin component for first actual leg
      if (isFirst) {
        journeyComponents.add(_buildOriginComponent(context, leg.origin));
      }

      // Check if there's an interchange between this leg and the previous actual leg
      if (!isFirst) {
        final previousLegIndex = actualLegIndices[i - 1];
        final previousLeg = journey.legs[previousLegIndex];

        // Check if we need to show an interchange component
        bool shouldShowInterchange = false;
        bool showInterchangeTime = true;
        String? platformChangeText;

        // Case 1: There are legs between previous and current that represent interchanges
        if (legIndex - previousLegIndex > 1) {
          // Find the interchange leg(s) between them
          for (
            int interchangeIndex = previousLegIndex + 1;
            interchangeIndex < legIndex;
            interchangeIndex++
          ) {
            final interchangeLeg = journey.legs[interchangeIndex];

            // If this is a same-station interchange
            if (interchangeLeg.origin.id == interchangeLeg.destination.id &&
                interchangeLeg.origin.name == interchangeLeg.destination.name) {
              shouldShowInterchange = true;
              platformChangeText = _getPlatformChangeText(
                interchangeLeg,
                interchangeIndex,
                journey.legs,
              );
              break;
            }
          }
        }
        // Case 2: Direct connection between different modes (e.g., walking to transit)
        else if (previousLeg.destination.id == leg.origin.id &&
            previousLeg.destination.name == leg.origin.name &&
            ((previousLeg.isWalking == true && leg.isWalking != true) ||
                (previousLeg.isWalking != true && leg.isWalking == true) ||
                (previousLeg.isWalking != true &&
                    leg.isWalking != true &&
                    previousLeg.lineName != leg.lineName))) {
          shouldShowInterchange = true;
          showInterchangeTime = false;

          // Check for platform changes
          if (previousLeg.arrivalPlatformEffective.isNotEmpty &&
              leg.departurePlatformEffective.isNotEmpty &&
              previousLeg.arrivalPlatformEffective !=
                  leg.departurePlatformEffective) {
            platformChangeText =
                'Platform change: ${previousLeg.arrivalPlatformEffective} to ${leg.departurePlatformEffective}';
          }
        }

        // Only add interchange component if it should be shown and it's not an empty container
        Widget interchangeWidget;
        if (shouldShowInterchange) {
          interchangeWidget = _buildInterchangeComponent(
            context,
            previousLeg, // Arriving leg
            leg, // Departing leg
            platformChangeText,
            showInterchangeTime
          );

        for(int i = 0; i < previousRil100Ids.length; i++)
          {
            if(previousRil100Ids[i] == leg.origin.ril100Ids[i] && shouldShowInterchange)
            {
              interchangeWidget = _buildInterchangeComponent(context, journey.legs[previousLegIndex - 1], leg, platformChangeText, showInterchangeTime);
            }
          }
          


          // Only add if it's not a SizedBox.shrink or empty container
          if (interchangeWidget is! SizedBox ||
              (interchangeWidget as SizedBox).height != 0) {
            journeyComponents.add(interchangeWidget);
          }


        }
      }

      // Add the actual leg component
      if (leg.isWalking == true) {
        journeyComponents.add(
          _buildWalkingLegCard(context, leg, legIndex, journey.legs),
        );
      } else {
        journeyComponents.add(
          _buildLegCard(context, leg, legIndex, journey.legs),
        );
      }

      // Add connection line if not last
      if (!isLast) {
        // journeyComponents.add(_buildConnectionLine(context));
      }

      // Add destination component for last actual leg
      if (isLast) {
        journeyComponents.add(
          _buildDestinationComponent(context, leg.destination),
        );
      }
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: journeyComponents.length,
      itemBuilder: (context, index) {
        return journeyComponents[index];
      },
    );
  }

  Widget _buildInterchangeComponent(
    BuildContext context,
    Leg arrivingLeg,
    Leg departingLeg,
    String? platformChangeText,
    bool showInterchangeTime
  ) {
    Color arrivalTimeColor = Theme.of(context).colorScheme.onSurface;
    Color departureTimeColor = Theme.of(context).colorScheme.onPrimary;
    Color arrivalPlatformColor = Theme.of(context).colorScheme.onSurface;
    Color departurePlatformColor = Theme.of(context).colorScheme.onPrimary;

    if (arrivingLeg.arrivalDelayMinutes != null) {
      if (arrivingLeg.arrivalDelayMinutes! > 10) {
        arrivalTimeColor = Theme.of(context).colorScheme.error;
      } else if (arrivingLeg.arrivalDelayMinutes! > 0) {
        arrivalTimeColor = Theme.of(context).colorScheme.tertiary;
      }
    }

    if (departingLeg.departureDelayMinutes != null) {
      if (departingLeg.departureDelayMinutes! > 10) {
        departureTimeColor = Theme.of(context).colorScheme.error;
      } else if (departingLeg.departureDelayMinutes! > 0) {
        departureTimeColor = Theme.of(context).colorScheme.onPrimary;
      }
    }

    if (arrivingLeg.arrivalPlatform != arrivingLeg.arrivalPlatformEffective) {
      arrivalPlatformColor = Theme.of(context).colorScheme.error;
    }

    if (departingLeg.departurePlatform !=
        departingLeg.departurePlatformEffective) {
      departurePlatformColor = Theme.of(context).colorScheme.error;
    }

    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    double height = 220;
    int upperFlex = 60;
    if(!showInterchangeTime)
    {
      height -= 21;
      upperFlex += 18;
    }

    return Column(
      children: [
        SizedBox(
          height: height, // Reduced from 300
          child: Column(
            children: [
              Flexible(
                flex: upperFlex,
                child: Container(
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Reduced from 8.0
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        color: colorScheme.surfaceContainerLowest,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16,4,16,4), // Reduced from 16
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Arrival ' + arrivingLeg.effectiveArrivalFormatted,
                              style: textTheme.titleMedium!.copyWith(
                                color: arrivalTimeColor,
                              ),
                            ),
                            if (arrivingLeg.arrivalPlatform == null)
                              Text('at the Station', style: textTheme.bodySmall),
                            if (arrivingLeg.arrivalPlatform != null)
                              Text(
                                'Platform ' + arrivingLeg.effectiveArrivalPlatform,
                                style: textTheme.bodySmall!.copyWith(
                                  color: arrivalPlatformColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 120,
                child: Container(
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0), // Reduced from 24.0
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                departingLeg.origin.name,
                                style: textTheme.headlineMedium,
                              ),
                              if (departingLeg.departureDateTime
                                      .difference(arrivingLeg.arrivalDateTime)
                                      .inMinutes <
                                  4)
                                if(showInterchangeTime)
                                Text(
                                  'Interchange Time: ' +
                                      departingLeg.departureDateTime
                                          .difference(arrivingLeg.arrivalDateTime)
                                          .inMinutes
                                          .toString() +
                                      ' min',
                                  style: textTheme.titleSmall!.copyWith(color: colorScheme.error),
                                ),
                                if (departingLeg.departureDateTime
                                      .difference(arrivingLeg.arrivalDateTime)
                                      .inMinutes >=
                                  4)
                                if(showInterchangeTime)
                                Text(
                                  'Interchange Time: ' +
                                      departingLeg.departureDateTime
                                          .difference(arrivingLeg.arrivalDateTime)
                                          .inMinutes
                                          .toString() +
                                      ' min', 
                                  style: textTheme.titleSmall,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8), // Reduced from 16
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: 60, // Reduced from 80
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 16,
                              children: [
                                if (departingLeg.lineName != null &&
                                    departingLeg.direction != null)
                                  DottedBorder(
                                    options: RoundedRectDottedBorderOptions(
                                      radius: Radius.circular(16),
                                    ),
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(24),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0), // Reduced from 8.0
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          spacing: 2,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(8),
                                                ),
                                                color: colorScheme.tertiaryContainer,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.fromLTRB(4, 1, 4, 1),
                                                child: Text(
                                                  departingLeg.lineName!,
                                                  style: textTheme.titleSmall,
                                                ),
                                              ),
                                            ),
                                            Text(departingLeg.direction!, style: textTheme.bodySmall,),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(16),
                                    ),
                                    color: colorScheme.primary,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16,4,16,4), // Reduced from 16
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Departure ' +
                                              departingLeg.effectiveDepartureFormatted,
                                          style: textTheme.titleMedium!.copyWith(
                                            color: departureTimeColor,
                                          ),
                                        ),
                                        if (departingLeg.departurePlatform == null)
                                          Text(
                                            'at the Station',
                                            style: textTheme.bodyMedium!.copyWith(
                                              color: colorScheme.onPrimary),
                                          ),
                                        if (departingLeg.departurePlatform != null)
                                          Text(
                                            'Platform ' +
                                                departingLeg.effectiveDeparturePlatform,
                                            style: textTheme.bodyMedium!.copyWith(
                                              color: departurePlatformColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOriginComponent(BuildContext context, Station s) {
    return Container();
  }

  Widget _buildDestinationComponent(BuildContext context, Station s) {
    return Container();
  }

  Widget _buildWalkingLegCard(
    BuildContext context,
    Leg leg,
    int index,
    List<Leg> legs,
  ) {
    if (leg.distance == null || leg.distance == 0) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
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
                ),
                const SizedBox(width: 8),
                _buildDurationChip(context, leg),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_right,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leg.destination.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => {},
                  icon: Icon(Icons.map),
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(leg.departureDateTime),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(leg.arrivalDateTime),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegCard(
    BuildContext context,
    Leg leg,
    int index,
    List<Leg> legs,
  ) {
    // Skip walking legs with zero or null distance
    if (leg.isWalking == true && (leg.distance == null || leg.distance == 0)) {
      return const SizedBox.shrink();
    }

    final platformChangeText = _getPlatformChangeText(leg, index, legs);
    final hasDelay = leg.hasDelays;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
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
    BuildContext context,
    Leg leg,
    String? platformChangeText,
    bool hasDelay,
  ) {
    return Row(
      children: [
        _buildLegIcon(context, leg),
        const SizedBox(width: 12),
        Expanded(child: _buildLegTitle(context, leg, platformChangeText)),
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
    BuildContext context,
    Leg leg,
    String? platformChangeText,
  ) {
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
    BuildContext context,
    String platformChangeText,
  ) {
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
          flags:
              InteractiveFlag.drag |
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
        // Add the polyline layer with route path
        _buildPolylineLayer(),
        CurrentLocationLayer(
          alignPositionOnUpdate: AlignOnUpdate.never,
          alignDirectionOnUpdate: AlignOnUpdate.never,
          style: LocationMarkerStyle(
            marker: DefaultLocationMarker(color: Colors.lightBlue[800]!),
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

  Widget _buildPolylineLayer() {
    // Get the colored polylines by leg
    final List<Polyline> polylines = _extractPolylinesByLeg();

    if (polylines.isEmpty) {
      print("DEBUG: No polylines created for journey legs");
      return const SizedBox.shrink();
    }

    print("DEBUG: Created ${polylines.length} polylines for journey legs");

    // Return the PolylineLayer with all our colored polylines
    return PolylineLayer(polylines: polylines);
  }

  List<LatLng> _extractRoutePointsFromLegs() {
    List<LatLng> allPoints = [];

    try {
      // Iterate through each leg to extract polyline data
      for (final leg in widget.journey.legs) {
        if (leg.polyline == null) continue;

        final dynamic polylineData = leg.polyline;

        // Parse the GeoJSON data
        final Map<String, dynamic> geoJson =
            polylineData is Map<String, dynamic>
            ? polylineData
            : jsonDecode(polylineData);

        if (geoJson['type'] == 'FeatureCollection' &&
            geoJson['features'] is List) {
          final List features = geoJson['features'];

          for (final feature in features) {
            if (feature['geometry'] != null &&
                feature['geometry']['type'] == 'Point' &&
                feature['geometry']['coordinates'] is List) {
              final List coords = feature['geometry']['coordinates'];

              // GeoJSON uses [longitude, latitude] format
              if (coords.length >= 2) {
                final double lng = coords[0] is double
                    ? coords[0]
                    : double.parse(coords[0].toString());
                final double lat = coords[1] is double
                    ? coords[1]
                    : double.parse(coords[1].toString());
                allPoints.add(LatLng(lat, lng));
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing leg polyline data: $e');
    }

    return allPoints;
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

  // Add this as a class field
  final Map<String, Color> _transitLineColorCache = {};

  List<Polyline> _extractPolylinesByLeg() {
    List<Polyline> polylines = [];
    final Map<String, Color> modeColors = {
      'train': const Color(0xFF9C27B0), // Purple for trains
      'subway': const Color(0xFF0075BF), // Blue for subway/metro
      'tram': const Color(0xFFE4000F), // Red for trams
      'bus': const Color(0xFF9A258F), // Magenta for buses
      'ferry': const Color(0xFF0098D8), // Light blue for ferries
      'walking': Colors.grey, // Grey for walking
      'default': Colors.blue, // Default blue
    };

    try {
      for (int i = 0; i < widget.journey.legs.length; i++) {
        final leg = widget.journey.legs[i];
        if (leg.polyline == null) continue;

        final List<LatLng> legPoints = _extractPointsFromLegPolyline(
          leg.polyline,
        );
        if (legPoints.isEmpty) continue;

        // Determine color based on transit info
        Color lineColor;

        if (leg.isWalking == true) {
          lineColor = modeColors['walking']!;
        } else {
          // Create a cache key using available properties
          final String cacheKey =
              '${leg.lineName ?? ''}-${leg.productName ?? ''}';
          String productType = leg.productName?.toLowerCase() ?? 'default';

          // Use cached color if available, otherwise use product-specific color
          lineColor =
              _transitLineColorCache[cacheKey] ??
              modeColors[productType] ??
              modeColors['default']!;

          // If not in cache yet, schedule async lookup but don't wait for it
          if (!_transitLineColorCache.containsKey(cacheKey) &&
              leg.lineName != null &&
              leg.lineName!.isNotEmpty &&
              legPoints.isNotEmpty) {
            LatLng centerPoint = legPoints[legPoints.length ~/ 2];
            final overpass = Overpassapi();

            // Start the async call but don't block polyline creation
            overpass
                .getTransitLineColor(
                  lat: centerPoint.latitude,
                  lon: centerPoint.longitude,
                  lineName: leg.lineName!,
                  mode: leg.productName,
                )
                .then((color) {
                  if (mounted && color != null) {
                    setState(() {
                      _transitLineColorCache[cacheKey] = color as Color;
                      // The setState will trigger rebuild with the new colors
                    });
                  }
                });
          }
        }

        final double strokeWidth = leg.isWalking == true ? 3.0 : 4.0;

        polylines.add(
          Polyline(
            points: legPoints,
            color: lineColor,
            strokeWidth: strokeWidth,
            pattern: leg.isWalking == true
                ? StrokePattern.dotted()
                : StrokePattern.solid(),
          ),
        );
      }
    } catch (e) {
      print('Error creating polylines: $e');
    }

    return polylines;
  }

  List<LatLng> _extractPointsFromLegPolyline(dynamic polylineData) {
    List<LatLng> points = [];

    try {
      final Map<String, dynamic> geoJson = polylineData is Map<String, dynamic>
          ? polylineData
          : jsonDecode(polylineData);

      if (geoJson['type'] == 'FeatureCollection' &&
          geoJson['features'] is List) {
        final List features = geoJson['features'];

        for (final feature in features) {
          if (feature['geometry'] != null &&
              feature['geometry']['type'] == 'Point' &&
              feature['geometry']['coordinates'] is List) {
            final List coords = feature['geometry']['coordinates'];

            if (coords.length >= 2) {
              final double lng = coords[0] is double
                  ? coords[0]
                  : double.parse(coords[0].toString());
              final double lat = coords[1] is double
                  ? coords[1]
                  : double.parse(coords[1].toString());
              points.add(LatLng(lat, lng));
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing leg polyline points: $e');
    }

    return points;
  }
}
