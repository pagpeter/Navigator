import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigator/pages/page_models/journey_page.dart';

class JourneyPageAndroid extends StatefulWidget {
  final JourneyPage page;

  const JourneyPageAndroid(this.page, {Key? key}) : super(key: key);

  @override
  State<JourneyPageAndroid> createState() => _JourneyPageAndroidState();
}

class _JourneyPageAndroidState extends State<JourneyPageAndroid> {
  // 1) Create a controller for your DraggableScrollableSheet
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _minChildSize = 0.1;
  static const double _maxChildSize = 1.0;
  static const double _initialChildSize = 0.6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMapView(context),
          DraggableScrollableSheet(
            // 2) Hook up the controller here
            controller: _sheetController,
            initialChildSize: _initialChildSize,
            minChildSize: _minChildSize,
            maxChildSize: _maxChildSize,
            snap: true,
            snapSizes: [0.1, 0.4, 0.6, 1],
            builder: (context, scrollController) {
              return Material(
                elevation: 6,
                color: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // 3) Wrap handle in GestureDetector to push drags into the controller
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (details) {
                        // details.primaryDelta is how many logical pixels the pointer moved since last update.
                        // We convert that to a fraction of screen-height to drive controller.size.
                        final fractionDelta =
                            details.primaryDelta! / MediaQuery.of(context).size.height;
                        final newSize = (_sheetController.size - fractionDelta)
                            .clamp(_minChildSize, _maxChildSize);
                        // jumpTo immediately moves sheet to the new size fraction
                        _sheetController.jumpTo(newSize);
                      },
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildJourneyView(context, scrollController),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }

  // ... _buildMapView & _buildJourneyView unchanged ...

  Widget _buildJourneyView(BuildContext context, ScrollController sc) {
    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Journey View Content'),
        SizedBox(height: 400), // Mock content for scrolling
        Text('More content...'),Text('Journey View Content'),
        SizedBox(height: 400), // Mock content for scrolling
        Text('More content...'),Text('Journey View Content'),
        SizedBox(height: 400), // Mock content for scrolling
        Text('More content...'),Text('Journey View Content'),
        SizedBox(height: 400), // Mock content for scrolling
        Text('More content...'),Text('Journey View Content'),
        SizedBox(height: 400), // Mock content for scrolling
        Text('More content...'),
      ],
    );
  }

  Widget _buildLeg(BuildContext context)
  {
    return Column();
  }

  Widget _buildMapView(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(52.513416, 13.412364),
        initialZoom: 9.2,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
      ],
    );
  }
}
