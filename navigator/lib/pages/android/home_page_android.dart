import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/pages/android/connections_page_android.dart';
import 'package:navigator/pages/page_models/connections_page.dart';
import 'package:navigator/pages/page_models/home_page.dart';
import 'package:navigator/models/station.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePageAndroid extends StatefulWidget {
  final HomePage page;
  final bool ongoingJourney;

  const HomePageAndroid(this.page, this.ongoingJourney, {Key? key})
    : super(key: key);

  @override
  State<HomePageAndroid> createState() => _HomePageAndroidState();
}

class _HomePageAndroidState extends State<HomePageAndroid> {
  final TextEditingController _controller = TextEditingController();
  List<Location> _searchResults = [];
  String _lastSearchedText = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      _onSearchChanged(_controller.text.trim());
    });
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
    final results = await widget.page.getLocations(query); // async method
    setState(() {
      _searchResults = results;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
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
        // clear the search and go back to the map
        setState(() {
          _searchResults.clear();
          _lastSearchedText = '';
          _controller.clear();
        });
        return false; // prevent actual pop
      }
      return true; // allow actual back navigation if no results
    },
    child: Scaffold(
      backgroundColor: colors.surfaceVariant,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: hasResults
            ? SafeArea(
              child: ListView.builder(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, bottomSheetHeight + 16),
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
                options: MapOptions(
                  initialCenter: LatLng(52.513416, 13.412364),
                  initialZoom: 9.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                ],
              ),
      ),
      bottomSheet: Material(
        color: colors.surfaceContainerHighest,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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


Widget _stationResult(BuildContext context, Station station) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  return Card(
    clipBehavior: Clip.hardEdge,
    color: colors.surfaceContainerHighest,
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
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