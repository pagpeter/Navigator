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
    // Helper function to safely get string values
    String safeGetString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    // Helper function to safely get nested string values
    String safeGetNestedString(Map<String, dynamic>? parent, String key) {
      if (parent == null) return '';
      final value = parent[key];
      if (value == null) return '';
      return value.toString();
    }

    // Safe station parsing
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
      direction: safeGetNestedString(json['line'], 'direction'),
      origin: safeGetStation(json['origin']),
      departure: safeGetString(json['departure']),
      plannedDeparture: safeGetString(json['plannedDeparture']),
      departureDelay: safeGetString(json['departureDelay']),
      departurePlatform: safeGetString(json['departurePlatform']),
      plannedDeparturePlatform: safeGetString(json['plannedDeparturePlatform']),
      destination: safeGetStation(json['destination']),
      arrival: safeGetString(json['arrival']),
      plannedArrival: safeGetString(json['plannedArrival']),
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