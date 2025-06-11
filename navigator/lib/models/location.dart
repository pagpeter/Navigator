import 'package:flutter/foundation.dart';

class Location {
  final String type;
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  Location({
    required this.type,
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      type: json['type'],
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}
