import 'package:navigator/models/station.dart';

class Leg {
  final String? tripID;
  final String? direction;
  final Station origin;
  final String departure;
  final String plannedDeparture;
  final String? departureDelay;
  final String? departurePlatform;
  final String? plannedDeparturePlatform;
  final Station destination;
  final String arrival;
  final String plannedArrival;
  final String? arrivalDelay;
  final String? arrivalPlatform;
  final String? plannedArrivalPlatform;

  // Additional fields that might be useful from the API
  final bool? isWalking;
  final int? distance;
  final String? lineName;
  final String? productName;

  Leg({
    this.tripID,
    this.direction,
    required this.origin,
    required this.departure,
    required this.plannedDeparture,
    this.departureDelay,
    this.departurePlatform,
    this.plannedDeparturePlatform,
    required this.destination,
    required this.arrival,
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
    return Leg(
      tripID: json['tripId'],
      direction: json['direction'],
      origin: Station.fromJson(json['origin']),
      departure: json['departure'],
      plannedDeparture: json['plannedDeparture'],
      departureDelay: json['departureDelay']?.toString(),
      departurePlatform: json['departurePlatform'],
      plannedDeparturePlatform: json['plannedDeparturePlatform'],
      destination: Station.fromJson(json['destination']),
      arrival: json['arrival'],
      plannedArrival: json['plannedArrival'],
      arrivalDelay: json['arrivalDelay']?.toString(),
      arrivalPlatform: json['arrivalPlatform'],
      plannedArrivalPlatform: json['plannedArrivalPlatform'],
      isWalking: json['walking'],
      distance: json['distance'],
      lineName: json['line']?['name'],
      productName: json['line']?['productName'],
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
      'line': lineName != null ? {
        'name': lineName,
        'productName': productName,
      } : null,
    };
  }

  @override
  String toString() {
    if (isWalking == true) {
      return 'Walking from ${origin.name} to ${destination.name} (${distance}m, ${_formatDuration()})';
    }
    return '$lineName from ${origin.name} to ${destination.name} '
        '(${departure.split('T')[1].substring(0, 5)} - ${arrival.split('T')[1].substring(0, 5)})';
  }

  String _formatDuration() {
    final dep = DateTime.parse(departure);
    final arr = DateTime.parse(arrival);
    final duration = arr.difference(dep);
    return '${duration.inMinutes}min';
  }

  // Helper method to check if there are delays
  bool get hasDelays => departureDelay != null || arrivalDelay != null;

  // Helper method to get delay in minutes
  int? get departureDelayMinutes {
    if (departureDelay == null) return null;
    return int.tryParse(departureDelay!);
  }

  int? get arrivalDelayMinutes {
    if (arrivalDelay == null) return null;
    return int.tryParse(arrivalDelay!);
  }

  DateTime get departureDateTime {
  final parsed = DateTime.parse(departure);
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime get arrivalDateTime {
  final parsed = DateTime.parse(arrival);
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime get plannedDepartureDateTime {
  final parsed = DateTime.parse(plannedDeparture);
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime get plannedArrivalDateTime {
  final parsed = DateTime.parse(plannedArrival);
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

}