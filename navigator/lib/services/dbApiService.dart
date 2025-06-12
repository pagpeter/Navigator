import 'dart:convert';
import 'package:navigator/models/dateAndTime.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/location.dart';
import 'package:navigator/models/station.dart';
import 'package:http/http.dart' as http;
import 'package:navigator/env/env.dart';


class dbApiService {
  final base_url = Env.api_url;

  // Future<List<Journey>> fetchJourneys(int fromId, int toId, DateAndTime when, bool departure) async
  // {
  //   final uri;
  //   if(departure)
  //   {
  //     uri = Uri.http(base_url, '/journeys', {
  //     'from': fromId,
  //     'to': toId,
  //     'departure': when.ISO8601String()
  //     }
  //     );
  //   }
  //   else
  //   {
  //     uri = Uri.http(base_url, '/journeys',
  //     {
  //       'from': fromId,
  //       'to': toId,
  //       'arrival': when.ISO8601String()
  //     });
  //   }

  //   final response = await http.get(uri);

  //   if(response.statusCode == 200)
  //   {
  //     final data = jsonDecode(utf8.decode(response.bodyBytes));
  //     print(jsonEncode(data));

  //     return (data as List)
  //     .map<Journey>((item)
  //     {

  //     })
  //   }


      
    
  // }

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
