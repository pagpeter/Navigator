import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navigator/models/subway_line.dart';

class Overpassapi {
  Future<List<SubwayLine>> fetchSubwayLinesWithColors({
    required double lat,
    required double lon,
    required int radius
  }) async {
    final query = '''
[out:json][timeout:60];
// Query around the specified coordinates (default: Berlin)
(
  relation["route"="subway"](around:$radius, $lat, $lon);
  relation["route"="light_rail"](around:$radius, $lat, $lon);
  relation["route"="tram"](around:$radius, $lat, $lon);
  relation["route"="ferry"](around:$radius, $lat, $lon);
  relation["route"="funicular"](around:$radius, $lat, $lon);
)->.r;
.r >> -> .x;
.x out geom;
''';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final response = await http.post(url, body: {'data': query});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return parseSubwayLinesFromOverpass(data);
    } else {
      throw Exception('Failed to fetch Overpass data');
    }
  }

  // Keep the old method for backward compatibility
  Future<List<List<LatLng>>> fetchSubwayLines({
    required double lat,
    required double lon,
    required int radius
  }) async {
    final subwayLines = await fetchSubwayLinesWithColors(lat: lat, lon: lon, radius: radius);
    return subwayLines.map((line) => line.points).toList();
  }

  List<SubwayLine> parseSubwayLinesFromOverpass(dynamic json) {
    final List<SubwayLine> subwayLines = [];
    
    // First, collect all subway relations with their metadata
    Map<int, Map<String, String>> relationData = {};
    
    for (var element in json['elements']) {
      if (element['type'] == 'relation' && 
          element.containsKey('tags') && 
          (element['tags']['route'] == 'subway' || 
          element['tags']['route'] == 'light_rail' ||
          element['tags']['route'] == 'tram' ||
          // element['tags']['route'] == 'bus' ||
          // element['tags']['route'] == 'trolleybus' ||
          element['tags']['route'] == 'ferry' ||
          element['tags']['route'] == 'funicular')) {
        
        final tags = element['tags'];
        relationData[element['id']] = {
          'color': tags['colour'] ?? tags['color'] ?? '',
          'name': tags['name'] ?? tags['ref'] ?? '',
          'ref': tags['ref'] ?? '',
          'type': tags['route'] ?? ''
        };
      }
    }
    
    // Group ways by their parent relations
    Map<int, List<int>> relationToWays = {};
    
    for (var element in json['elements']) {
      if (element['type'] == 'relation' && relationData.containsKey(element['id'])) {
        relationToWays[element['id']] = [];
        
        if (element.containsKey('members')) {
          for (var member in element['members']) {
            if (member['type'] == 'way') {
              relationToWays[element['id']]!.add(member['ref']);
            }
          }
        }
      }
    }
    
    // Now process each way as a separate polyline
    for (var relationId in relationData.keys) {
      final wayIds = relationToWays[relationId] ?? [];
      final relationInfo = relationData[relationId]!;
      
      // Create a separate SubwayLine for each way segment
      for (var element in json['elements']) {
        if (element['type'] == 'way' && 
            wayIds.contains(element['id']) &&
            element.containsKey('geometry')) {
          
          final geometry = element['geometry'];
          if (geometry is List && geometry.isNotEmpty) {
            final wayPoints = geometry.map<LatLng>((point) {
              return LatLng(point['lat'].toDouble(), point['lon'].toDouble());
            }).toList();
            
            // Create separate polyline for each way segment
            if (wayPoints.length >= 2) {
              subwayLines.add(SubwayLine(
                points: wayPoints,
                color: parseColorFromString(relationInfo['color']),
                lineName: relationInfo['name'],
                lineRef: relationInfo['ref'],
                type: relationInfo['type']
              ));
            }
          }
        }
      }
    }
    
    print("✅ Parsed ${subwayLines.length} subway line segments with colors.");
    
    // Debug: Print some color info
    final uniqueLines = <String, SubwayLine>{};
    for (var line in subwayLines) {
      final key = '${line.lineName}_${line.lineRef}';
      uniqueLines[key] = line;
    }
    
    for (var line in uniqueLines.values.take(5)) {
      print("Line: ${line.lineName} (${line.lineRef}) - Color: ${line.color}");
    }
    
    return subwayLines;
  }

  // Add this method to your existing Overpassapi class
  Future<Color> getTransitLineColor({
    required double lat,
    required double lon,
    required String lineName,
    String? lineRef,
    String? mode,
    int radius = 3000
  }) async {
    // Default colors by transport mode
    final Map<String, Color> defaultColors = {
      'train': const Color(0xFF006CB3),     // Blue for S-Bahn/Train
      'subway': const Color(0xFF00629E),    // Dark blue for U-Bahn
      'tram': const Color(0xFFE4000F),      // Red for trams
      'bus': const Color(0xFF9A258F),       // Purple for buses
      'ferry': const Color(0xFF0098D8),     // Light blue for ferries
      'light_rail': const Color(0xFF006CB3),// Same as train
      'funicular': const Color(0xFFE77817), // Orange for funicular
    };

    try {
      // Clean up line name for better matching
      String cleanLineName = lineName.trim();
      String? cleanLineRef = lineRef?.trim();
      String transportType = mode?.toLowerCase() ?? 'train';

      // Convert mode from journey to Overpass route type
      String routeType;
      switch (transportType) {
        case 'subway': routeType = 'subway'; break;
        case 'tram': routeType = 'tram'; break;
        case 'bus': routeType = 'bus'; break;
        case 'ferry': routeType = 'ferry'; break;
        case 'regional': routeType = 'train'; break;
        case 'suburban': routeType = 'light_rail'; break;
        default: routeType = 'train'; break;
      }

      // Build a more specific query for this transit line
// Build a more specific query for this transit line
      final query = '''
[out:json][timeout:30];
(
  relation["route"="$routeType"]${cleanLineRef != null ? '[ref~"^$cleanLineRef\$|^$cleanLineRef\\\\s|\\\\s$cleanLineRef\$|\\\\s$cleanLineRef\\\\s"]' : ''}${cleanLineName.isNotEmpty ? '[name~"$cleanLineName"]' : ''}(around:$radius, $lat, $lon);
)->.routes;
.routes out tags;
''';


      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(url, body: {'data': query});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['elements'] != null && data['elements'] is List && data['elements'].isNotEmpty) {
          // Try to find the exact match first
          for (var element in data['elements']) {
            if (element['tags'] != null) {
              final tags = element['tags'];
              final String? elementRef = tags['ref'];
              final String? elementName = tags['name'];

              bool isExactMatch = false;

              // Check if this is our line by ref or name
              if (cleanLineRef != null && elementRef != null) {
                isExactMatch = elementRef.trim() == cleanLineRef;
              } else if (elementName != null && cleanLineName.isNotEmpty) {
                isExactMatch = elementName.contains(cleanLineName);
              }

              if (isExactMatch && (tags['colour'] != null || tags['color'] != null)) {
                final colorStr = tags['colour'] ?? tags['color'];
                return parseColorFromString(colorStr);
              }
            }
          }

          // If we got here, we didn't find an exact match, so use the first line with color
          for (var element in data['elements']) {
            if (element['tags'] != null) {
              final tags = element['tags'];
              if (tags['colour'] != null || tags['color'] != null) {
                final colorStr = tags['colour'] ?? tags['color'];
                return parseColorFromString(colorStr);
              }
            }
          }
        }
      }

      // Return default color based on transport type if no match found
      return defaultColors[routeType] ?? Colors.blue;
    } catch (e) {
      print('Error fetching transit line color: $e');
      return Colors.blue;
    }
  }

// Method to use in your journey map to get colors for legs
  Color parseColorFromString(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) {
      return Colors.blue;
    }

    // Handle hex colors with or without # prefix
    String normalizedColor = colorStr.startsWith('#') ? colorStr.substring(1) : colorStr;

    // Handle 3-digit hex codes (expand to 6 digits)
    if (normalizedColor.length == 3) {
      normalizedColor = normalizedColor.split('').map((c) => '$c$c').join('');
    }

    // Add alpha channel if missing
    if (normalizedColor.length == 6) {
      normalizedColor = 'FF$normalizedColor';
    }

    try {
      return Color(int.parse(normalizedColor, radix: 16));
    } catch (e) {
      print('Invalid color format: $colorStr');
      return Colors.blue;
    }
  }
}