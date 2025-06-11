import 'dart:convert';
import 'package:navigator/models/location.dart';
import 'package:navigator/models/station.dart';
import 'package:http/http.dart' as http;

class dbApiService {
  String base_url = "185.230.138.40:3000";

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
    .where((item) => item['id'] != null && item['id'].toString().toLowerCase() != 'null')
    .map<Location>((item) {
      if (item['type'] == 'station') {
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
