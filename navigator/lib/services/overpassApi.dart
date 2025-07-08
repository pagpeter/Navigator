import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navigator/models/subway_line.dart';

import '../models/station.dart';

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

  Future<List<Station>> fetchStationsByType({
    required double lat,
    required double lon,
    required int radius,
  }) async {
    // Only fetch railway stations, subway entrances, and tram stops
    final query = '''
[out:json][timeout:60];
(
  node["railway"="station"](around:$radius,$lat,$lon);
  node["railway"="subway_entrance"](around:$radius,$lat,$lon);
  node["railway"="tram_stop"](around:$radius,$lat,$lon);
)->.stations;
.stations out body;
''';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final response = await http.post(url, body: {'data': query});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return parseStationsFromOverpass(data);
    } else {
      throw Exception('Failed to fetch station data');
    }
  }



  List<Station> parseStationsFromOverpass(dynamic json) {
    final List<Station> stations = [];

    for (var element in json['elements']) {
      if (element['type'] == 'node' && element.containsKey('tags')) {
        final tags = element['tags'];
        final name = tags['name'] ?? 'Unknown Station';

        stations.add(Station(
          type: 'station',
          id: element['id'].toString(),
          name: name,
          latitude: element['lat'].toDouble(),
          longitude: element['lon'].toDouble(),
          nationalExpress: tags['national_express'] == 'yes',
          national: tags['national'] == 'yes',
          regional: tags['regional'] == 'yes',
          regionalExpress: tags['regional_express'] == 'yes',
          suburban: tags['suburban'] == 'yes' || tags['transport_type'] == 'subway',
          bus: tags['bus'] == 'yes',
          ferry: tags['ferry'] == 'yes',
          subway: tags['subway'] == 'yes' || tags['transport_type'] == 'subway',
          tram: tags['tram'] == 'yes' || tags['transport_type'] == 'tram',
          taxi: tags['taxi'] == 'yes',
        ));
      }
    }

    print("✅ Parsed ${stations.length} stations");
    return stations;
  }
}