import 'package:navigator/models/station.dart';

class Leg {
  final String? tripID;
  final String? direction;
  final Station origin;
  final String? departure;
  final String plannedDeparture;
  final String? departureDelay;
  final String? departurePlatform;
  final String? plannedDeparturePlatform;
  final Station destination;
  final String? arrival;
  final String plannedArrival;
  final String? arrivalDelay;
  final String? arrivalPlatform;
  final String? plannedArrivalPlatform;

  // Additional fields
  final bool? isWalking;
  final int? distance;
  final String? lineName;
  final String? productName;

  Leg({
    this.tripID,
    this.direction,
    required this.origin,
    this.departure,
    required this.plannedDeparture,
    this.departureDelay,
    this.departurePlatform,
    this.plannedDeparturePlatform,
    required this.destination,
    this.arrival,
    required this.plannedArrival,
    this.arrivalDelay,
    this.arrivalPlatform,
    this.plannedArrivalPlatform,
    this.isWalking,
    this.distance,
    this.lineName,
    this.productName,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    String? safeGetString(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    String? safeGetNestedString(Map<String, dynamic>? parent, String key) {
      if (parent == null) return null;
      final value = parent[key];
      if (value == null) return null;
      return value.toString();
    }

    Station safeGetStation(dynamic stationJson) {
      if (stationJson == null) return Station.empty();
      try {
        return Station.fromJson(stationJson);
      } catch (e) {
        print('Error parsing station: $e');
        return Station.empty();
      }
    }

    return Leg(
      tripID: safeGetString(json['tripId']),
      direction: safeGetString(json['direction']),
      origin: safeGetStation(json['origin']),
      departure: safeGetString(json['departure']),
      plannedDeparture: safeGetString(json['plannedDeparture']) ?? '',
      departureDelay: safeGetString(json['departureDelay']),
      departurePlatform: safeGetString(json['departurePlatform']),
      plannedDeparturePlatform: safeGetString(json['plannedDeparturePlatform']),
      destination: safeGetStation(json['destination']),
      arrival: safeGetString(json['arrival']),
      plannedArrival: safeGetString(json['plannedArrival']) ?? '',
      arrivalDelay: safeGetString(json['arrivalDelay']),
      arrivalPlatform: safeGetString(json['arrivalPlatform']),
      plannedArrivalPlatform: safeGetString(json['plannedArrivalPlatform']),
      isWalking: json['walking'],
      distance: json['distance'],
      lineName: safeGetNestedString(json['line'], 'name'),
      productName: safeGetNestedString(json['line'], 'productName'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripId': tripID,
      'direction': direction,
      'origin': origin.toJson(),
      'departure': departure,
      'plannedDeparture': plannedDeparture,
      'departureDelay': departureDelay,
      'departurePlatform': departurePlatform,
      'plannedDeparturePlatform': plannedDeparturePlatform,
      'destination': destination.toJson(),
      'arrival': arrival,
      'plannedArrival': plannedArrival,
      'arrivalDelay': arrivalDelay,
      'arrivalPlatform': arrivalPlatform,
      'plannedArrivalPlatform': plannedArrivalPlatform,
      'walking': isWalking,
      'distance': distance,
      'line': lineName != null || productName != null ? {
        'name': lineName,
        'productName': productName,
      } : null,
    };
  }

  // Helper getters for effective times
  String get effectiveDeparture => departure ?? plannedDeparture;
  String get effectiveArrival => arrival ?? plannedArrival;
  String get effectiveDeparturePlatform =>
      departurePlatform ?? plannedDeparturePlatform ?? '';

  String get effectiveArrivalPlatform =>
      arrivalPlatform ?? plannedArrivalPlatform ?? '';

  @override
  String toString() {
    if (isWalking == true) {
      return 'Walking from ${origin.name} to ${destination.name} (${distance}m, ${_formatDuration()})';
    }
    String departureTime = '';
    String arrivalTime = '';
    try {
      departureTime = effectiveDeparture.split('T')[1].substring(0, 5);
      arrivalTime = effectiveArrival.split('T')[1].substring(0, 5);
    } catch (e) {
      departureTime = 'unknown';
      arrivalTime = 'unknown';
    }
    return '$lineName from ${origin.name} to ${destination.name} '
        '($departureTime - $arrivalTime)';
  }

  String _formatDuration() {
    try {
      if (effectiveDeparture.isEmpty || effectiveArrival.isEmpty) return 'unknown';
      final dep = DateTime.parse(effectiveDeparture);
      final arr = DateTime.parse(effectiveArrival);
      final duration = arr.difference(dep);
      return '${duration.inMinutes}min';
    } catch (e) {
      return 'unknown';
    }
  }

  DateTime get departureDateTime {
    final parsed = DateTime.parse(effectiveDeparture);
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime get arrivalDateTime {
    final parsed = DateTime.parse(effectiveArrival);
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime get plannedDepartureDateTime {
    final dateStr = plannedDeparture.isNotEmpty ? plannedDeparture : effectiveDeparture;
    final parsed = DateTime.parse(dateStr);
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime get plannedArrivalDateTime {
    final dateStr = plannedArrival.isNotEmpty ? plannedArrival : effectiveArrival;
    final parsed = DateTime.parse(dateStr);
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  bool get hasDelays {
    final depDelay = departureDelay != null ? int.tryParse(departureDelay!) ?? 0 : 0;
    final arrDelay = arrivalDelay != null ? int.tryParse(arrivalDelay!) ?? 0 : 0;
    return depDelay > 0 || arrDelay > 0;
  }

  int? get departureDelayMinutes {
    if (departureDelay == null) return null;

    final seconds = int.tryParse(departureDelay!);
    if (seconds == null) return null;

    return (seconds / 60).ceil();
  }

  int? get arrivalDelayMinutes {
    if (arrivalDelay == null) return null;

    final seconds = int.tryParse(arrivalDelay!);
    if (seconds == null) return null;

    return (seconds / 60).ceil();
  }

  bool platformChange(Leg nextLeg) {
    final currentArrival = arrivalPlatformEffective;
    final nextDeparture = nextLeg.departurePlatformEffective;
    return currentArrival.isNotEmpty &&
        nextDeparture.isNotEmpty &&
        currentArrival != nextDeparture;
  }

  // Returns actual departure platform, or planned, or empty string
  String get departurePlatformEffective =>
      departurePlatform?.isNotEmpty == true
          ? departurePlatform!
          : (plannedDeparturePlatform ?? '');

// Returns planned departure platform, or actual, or empty string
  String get plannedDeparturePlatformEffective =>
      plannedDeparturePlatform?.isNotEmpty == true
          ? plannedDeparturePlatform!
          : (departurePlatform ?? '');

// Returns actual arrival platform, or planned, or empty string
  String get arrivalPlatformEffective =>
      arrivalPlatform?.isNotEmpty == true
          ? arrivalPlatform!
          : (plannedArrivalPlatform ?? '');

// Returns planned arrival platform, or actual, or empty string
  String get plannedArrivalPlatformEffective =>
      plannedArrivalPlatform?.isNotEmpty == true
          ? plannedArrivalPlatform!
          : (arrivalPlatform ?? '');

}