import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:navigator/pages/page_models/home_page.dart';
import 'package:navigator/models/station.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  List<Station> _searchResults = [];
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
    final hasResults = _searchResults.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: hasResults
                    ? ListView.builder(
                        key: ValueKey('list'),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                          child: Card(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      FaIcon(FontAwesomeIcons.).,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4.0,
                                              left: 8.0,
                                              right: 8.0,
                                            ),
                                            child: Text(
                                              _searchResults[index].name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8.0,
                                              right: 8.0,
                                              bottom: 8.0,
                                            ),
                                            child: Row(
                                              spacing: 8,
                                              children: [
                                                if (_searchResults[index]
                                                        .national ||
                                                    _searchResults[index]
                                                        .nationalExpress)
                                                  Icon(Icons.directions_transit, color:Theme.of(context).colorScheme.onSecondaryFixed),
                                                if (_searchResults[index]
                                                        .regional ||
                                                    _searchResults[index]
                                                        .regionalExpress)
                                                  Icon(Icons.accessibility, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                                if (_searchResults[index]
                                                    .suburban)
                                                  Icon(Icons.directions_train, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                                if (_searchResults[index].bus)
                                                  Icon(Icons.directions_bus, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                                if (_searchResults[index].ferry)
                                                  Icon(Icons.directions_ferry, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                                if (_searchResults[index]
                                                    .subway)
                                                  Icon(Icons.subway, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                                if (_searchResults[index].tram)
                                                  Icon(Icons.tram, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                                if (_searchResults[index].taxi)
                                                  Icon(Icons.local_taxi, color:Theme.of(context).colorScheme.secondaryFixedDim),
                                              ],
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
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(52.513416, 13.412364),
                          initialZoom: 9.2,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                        ],
                      ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Where do you want to go?',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
}
