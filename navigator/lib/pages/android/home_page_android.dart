import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart';

class HomePageAndroid extends StatelessWidget {
  HomePageAndroid(this.page, this.ongoingJourney, {super.key});

  HomePage page;
  bool ongoingJourney;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(flex: 4, child: Center(child: Text('Map'))),
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
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }
}
