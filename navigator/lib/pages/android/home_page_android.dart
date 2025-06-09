import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart';

class HomePageAndroid extends HomePage {
  HomePageAndroid(this.page, this.ongoingJourney, {super.key});

  HomePage page;
  bool ongoingJourney;

  bool showList = false; // Toggle state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: showList
                    ? ListView.builder(
                        key: ValueKey('listView'), // Important for switch
                        itemCount: 15,
                        itemBuilder: (context, index) =>
                            ListTile(title: Text('Destination ${index + 1}')),
                      )
                    : Text(
                        'Map',
                        key: ValueKey('mapText'), // Important for switch
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.primaries.last,
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
                    color: Colors.primaries.first,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: TextField(
                      onTap: () {
                        // Trigger animation
                        showList = true;
                        (context as Element).markNeedsBuild(); // Force rebuild
                      },
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
