import 'dart:convert';
import 'package:core/models/station.dart';
import 'package:http/http.dart' as http;

class dbApiService 
{
  Future<List<Station>> fetchLocations() async 
  {
    final uri = Uri.parse('https://v6.db.transport.rest/locations').replace(queryParameters: {'poi': 'false','addresses': 'false','query': 'südkreuz',});

    final response = await http.get(uri);

    if (response.statusCode == 200) 
    {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print(jsonEncode(data)); // Pretty print or handle as needed
      return (data as List).map((item) => Station.fromJson(item)).toList();    
    } 
    else 
    {
      throw Exception('Failed to load locations: ${response.statusCode}');
    }
  }
}