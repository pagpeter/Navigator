import 'package:navigator/models/location.dart';

class Station extends Location {
  final bool nationalExpress;
  final bool national;
  final bool regional;
  final bool regionalExpress;
  final bool suburban;
  final bool bus;
  final bool ferry;
  final bool subway;
  final bool tram;
  final bool taxi;

  Station({
    required super.type,
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required this.nationalExpress,
    required this.national,
    required this.regional,
    required this.regionalExpress,
    required this.suburban,
    required this.bus,
    required this.ferry,
    required this.subway,
    required this.tram,
    required this.taxi,
  });

  factory Station.empty() {
    return Station(
      type: '',
      id: '',
      name: '',
      latitude: 0,
      longitude: 0,
      nationalExpress: false,
      national: false,
      regional: false,
      regionalExpress: false,
      suburban: false,
      bus: false,
      ferry: false,
      subway: false,
      tram: false,
      taxi: false,
    );
  }

  factory Station.fromJson(Map<String, dynamic> json) {

    final location = json['location'];
    final products = json['products'];

    return Station(
      type: json['type'] ?? '',
      id: json['id'] ?? location?['id'] ?? '',  // 👈 fallback if id is null
      name: json['name'] ?? '',
      latitude: location?['latitude'] ?? json['latitude'] ?? 0.0,
      longitude: location?['longitude'] ?? json['longitude'] ?? 0.0,
      nationalExpress: products?['nationalExpress'] ?? false,
      national: products?['national'] ?? false,
      regional: products?['regional'] ?? false,
      regionalExpress: products?['regionalExpress'] ?? false,
      suburban: products?['suburban'] ?? false,
      bus: products?['bus'] ?? false,
      ferry: products?['ferry'] ?? false,
      subway: products?['subway'] ?? false,
      tram: products?['tram'] ?? false,
      taxi: products?['taxi'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'name': name,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'products': {
        'nationalExpress': nationalExpress,
        'national': national,
        'regional': regional,
        'regionalExpress': regionalExpress,
        'suburban': suburban,
        'bus': bus,
        'ferry': ferry,
        'subway': subway,
        'tram': tram,
        'taxi': taxi,
      },
    };
  }
}
