import 'package:flutter/material.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/models/station.dart';
import 'package:navigator/pages/page_models/connections_page.dart';
import 'package:navigator/pages/page_models/home_page.dart';

class ConnectionsPageAndroid extends StatefulWidget {
  ConnectionsPageAndroid(this.page, this.to, {super.key});

  ConnectionsPage page;
  Location to;

  @override
  Widget build(BuildContext context) {
    return Text(to.name);
  }

  State<ConnectionsPageAndroid> createState() => _ConnectionsPageAndroidState();
}

class _ConnectionsPageAndroidState extends State<ConnectionsPageAndroid> {
  void initState() {
    super.initState();
  }

  void dispose() {
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            //Search Options
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                color: Theme.of(context).colorScheme.primaryFixedDim,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildInputField(
                          context,
                          Icons.radio_button_checked,
                          "Von",
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(context, Icons.location_on, "Nach"),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      top:
                          34, // Adjust this to center the button between the fields
                      child: FloatingActionButton.small(
                        onPressed: () {
                          // Switch action here
                        },
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.swap_vert),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Text(widget.to.name),
          ],
        ),
      ),

      // Connections
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context,
    IconData icon,
    String hintText,
  ) {
    return TextField(
      decoration: InputDecoration(
        hintText: hintText,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primaryFixed,
            width: 2,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.onPrimaryFixed,
            width: 2,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}
