import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/pages/page_models/connections_page.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:navigator/models/dateAndTime.dart';




class ConnectionsPageAndroid extends StatefulWidget
{
  final ConnectionsPage page;


  const ConnectionsPageAndroid(this.page, {super.key});
  @override
  State<ConnectionsPageAndroid> createState() => _ConnectionsPageAndroidState();
}

class _ConnectionsPageAndroidState extends State<ConnectionsPageAndroid>
{
  //Variables

  late final TextEditingController _toController;
  late final TextEditingController _fromController;
  late TimeOfDay _selectedTime;
  late DateTime _selectedDate;
  late Position _selectedPosition;
  late List<Journey> _currentJourneys;
  late List<Location> _searchResultsFrom; 
  late List<Location> _searchResultsTo;
  String _lastSearchedText = '';
  Timer? _debounce;
  late FocusNode _fromFocusNode;
  late FocusNode _toFocusNode;
  bool departure = true;
  bool searching = false;
  bool searchingFrom = true;


  @override
  void initState() {
    super.initState();
    //Initializers
    updateLocationWithCurrentPosition(widget.page.from);
    _fromFocusNode = FocusNode();
    _toFocusNode = FocusNode();
    _toController = TextEditingController(text: widget.page.to?.name);
    _fromController = TextEditingController();
    _selectedTime = TimeOfDay.now();
    _selectedDate = DateTime.now();

    _fromFocusNode.addListener(()
    {
      if(!_fromFocusNode.hasFocus)
      {
        setState(() {
          _searchResultsFrom.clear();
          searching = false;
        });
      }
    });

    _toFocusNode.addListener(()
    {
      if(!_toFocusNode.hasFocus)
      {
        setState(() {
          _searchResultsTo.clear();
          searching = false;
        });
      }
    });

    _fromFocusNode.addListener(()
    {
      if(_fromFocusNode.hasFocus)
      {
        setState(() {
          searching = true;
          searchingFrom = true;
        });
      }
    });

    _toFocusNode.addListener(()
    {
      if(_toFocusNode.hasFocus)
      {
        setState(() {
          searching = true;
          searchingFrom = false;
        });
      }
    });

    _toController.addListener(()
    {
      _onSearchChanged(_toController.text.trim(), false);
    });

    _fromController.addListener(()
    {
      _onSearchChanged(_fromController.text.trim(), true);
    });

  }


  //Helper Functions
  void _onSearchChanged(String query, bool from) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query != _lastSearchedText) {
        getSearchResults(query, from);
        _lastSearchedText = query;
      }
    });
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


  //async to Sync functions
  Future<void> updateLocationWithCurrentPosition(Location l) async
  {
    l = await widget.page.services.getCurrentLocation();
  }

  Future<void> getSearchResults(String query, bool from) async
  {
    final results = await widget.page.services.getLocations(query);
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
      name: widget.page.to.name,
      type: widget.page.to.type,
      address: toAddress,
    )
        : Location(
      id: toId,
      latitude: toLat,
      longitude: toLong,
      name: widget.page.to.name,
      type: widget.page.to.type,
      address: null,
    );

    final journeys = await widget.page.services.getJourneys(
      from,
      to,
      when,
      departure,
    );

    setState(() {
      _currentJourneys = journeys;
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
      id: widget.page.to.id,
      latitude: widget.page.to.latitude,
      longitude: widget.page.to.longitude,
      name: widget.page.to.name,
      type: widget.page.to.type,
      address: null,
    );

    final journeys = await widget.page.services.getJourneys(
      from,
      to,
      when,
      departure,
    );

    setState(() {
      _currentJourneys = journeys;
    });
  }

  @override 
  Widget build(BuildContext context)
  {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        //Input Fields
        //Search related Buttons
        //Results
        
      ],),)),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }

}