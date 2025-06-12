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

class ConnectionsPageAndroid extends StatefulWidget {
  ConnectionsPageAndroid(this.page, this.to, {super.key});

  ConnectionsPage page;
  Location to;
  ServicesMiddle services = ServicesMiddle();

  @override
  Widget build(BuildContext context) {
    return Text(to.name);
  }

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

  void initState() {
    super.initState();
    _toController = TextEditingController(text: widget.to.name);
    _fromController = TextEditingController();
    _selectedTime = TimeOfDay.now();
    _selectedDate = DateTime.now();
    geoService = GeoService();
    _getCurrentLocation();
    bool hasJourneys = _currentJourneys.isNotEmpty;

  }

  void dispose() {
    super.dispose();
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
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            context,
                            Icons.location_on,
                            "To",
                            _toController,
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
                  IconButton.outlined(
                    onPressed: () => {},
                    icon: Icon(Icons.refresh),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => {},
                    icon: Icon(Icons.settings),
                  ),
                ],
              ),
              // Jorneys
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
    if(!hasJourneys)
    {
      //loading indicator
      return CircularProgressIndicator();
    }
    else{
    TextTheme textTheme = Theme.of(context).textTheme;
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: colorScheme.tertiaryContainer.withAlpha(120),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: ListView.builder(
          key: const ValueKey('list'),
          itemCount: 8,
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
                                    fit: BoxFit.cover, // covers the full height
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
  ) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: (_) {}, // keep your debounce logic upstream
      style: TextStyle(color: colors.onSurface),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIcon: Icon(icon, color: colors.primary),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get Location. Error code: $err')),
      );
    }
  }

  TextEditingController _updateControllerWithLocation(TextEditingController c) {
    if (_selectedPosition != null) {
      c.text = 'Current Position';
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

    Location from;
    Location to;

    if(fromId == null)
    {
      from = Location(id: "0", latitude: fromLat, longitude: fromLon, name: "", type: "");
    }
    else
    {
      from = Location(id: fromId, latitude: 0, longitude: 0, name: "", type: "");
    }

    if(toId == null)
    {
      to = Location(id: "0", latitude: toLat, longitude: toLong, name: "", type: "");
    }
    else
    {
      to = Location(id: toId, latitude: 0, longitude: 0, name: "", type: "");
    }

    
    _currentJourneys = await widget.services.getJourneys(from, to, when, departure);
  }
}
