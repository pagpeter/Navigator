import 'dart:convert';
import 'package:http/http.dart' as http;

class dbApiService 
{
  final String apiKey; // Your DB API key
  final String baseUrl = 'https://api.deutschebahn.com/freeplan/v1';
}