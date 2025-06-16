import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navigator/models/subway_line.dart';

class Overpassapi {
  Future<List<SubwayLine>> fetchSubwayLinesWithColors() async {
    const query = '''
[out:json][timeout:25];
area["name"="Berlin"]->.a;
(
  relation["route"="subway"](area.a);
  relation["route"="light_rail"](area.a);
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
  Future<List<List<LatLng>>> fetchSubwayLines() async {
    final subwayLines = await fetchSubwayLinesWithColors();
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
          element['tags']['route'] == 'light_rail')) {
        
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
}