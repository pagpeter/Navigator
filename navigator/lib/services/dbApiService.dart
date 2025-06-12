import 'dart:convert';
import 'package:navigator/models/dateAndTime.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/models/station.dart';
import 'package:http/http.dart' as http;
import 'package:navigator/env/env.dart';
import 'package:navigator/models/leg.dart';


class dbApiService {
  final base_url = Env.api_url;

Future<List<Journey>> fetchJourneysByLocation(
  Location from,
  Location to,
  DateAndTime when,
  bool departure,
) async {
  final queryParams = <String, String>{};

  // FROM
  if (from.id.isNotEmpty) {
    queryParams['from'] = from.id;
  } else {
    queryParams['from.latitude'] = from.latitude.toString();
    queryParams['from.longitude'] = from.longitude.toString();
  }

  // TO
  if (to.id.isNotEmpty) {
    queryParams['to'] = to.id;
  } else {
    queryParams['to.latitude'] = to.latitude.toString();
    queryParams['to.longitude'] = to.longitude.toString();
  }

  // TIME
  if (departure) {
    queryParams['departure'] = when.ISO8601String();
  } else {
    queryParams['arrival'] = when.ISO8601String();
  }

  final uri = Uri.http(base_url, '/journeys', queryParams);

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final journeysJson = data['journeys'] as List;

    return journeysJson.map<Journey>((journeyJson) {
      final legsJson = journeyJson['legs'] as List;

      List<Leg> legs = legsJson.map<Leg>((legJson) {
        final origin = Station.fromJson(legJson['origin']);
        final destination = Station.fromJson(legJson['destination']);

        return Leg(
          tripID: legJson['tripId'],
          direction: legJson['line']?['direction'] ?? '',
          origin: origin,
          departure: legJson['departure'] ?? '',
          plannedDeparture: legJson['plannedDeparture'] ?? '',
          departureDelay: legJson['departureDelay']?.toString() ?? '',
          departurePlatform: legJson['departurePlatform'] ?? '',
          plannedDeparturePlatform: legJson['plannedDeparturePlatform'] ?? '',
          destination: destination,
          arrival: legJson['arrival'] ?? '',
          plannedArrival: legJson['plannedArrival'] ?? '',
          arrivalDelay: legJson['arrivalDelay']?.toString() ?? '',
          arrivalPlatform: legJson['arrivalPlatform'] ?? '',
          plannedArrivalPlatform: legJson['plannedArrivalPlatform'] ?? '',
        );
      }).toList();

      return Journey(legs: legs);
    }).toList();
  } else {
    throw Exception('Failed to load journeys: ${response.statusCode}');
  }
}



  Future<List<Location>> fetchLocations(String query) async {
    final uri = Uri.http(base_url, '/locations', {
      'poi': 'false',
      'addresses': 'true',
      'query': query,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print(jsonEncode(data)); // Pretty print or handle as needed
      return (data as List)
    .where((item) => (item['id'] != null && item['id'].toString().toLowerCase() != 'null') || !(item['type'] != 'station' && item['latitude'] != null && item['longitude'] != null))
    .map<Location>((item) {
      if (item['type'] == 'station' || item['type'] == 'stop') {
        return Station.fromJson(item);
      } else {
        return Location.fromJson(item);
      }
    }).toList();
    } else {
      throw Exception('Failed to load locations: ${response.statusCode}');
    }
  }
}
