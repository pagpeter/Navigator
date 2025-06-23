import 'package:navigator/models/leg.dart';

class Journey {
  final List<Leg> legs;

  Journey({required this.legs});

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      legs: (json['legs'] as List)
          .map((legJson) => Leg.fromJson(legJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'legs': legs.map((leg) => leg.toJson()).toList(),
    };
  }

  // Static method to parse and sort journeys from JSON response
  static List<Journey> parseAndSort(List<dynamic> jsonJourneys) {
    // Parse all journeys from JSON
    List<Journey> journeys = jsonJourneys
        .map((json) => Journey.fromJson(json))
        .toList();

    // Sort by the actual departure time of the first leg
    // This accounts for delays and shows real chronological order
    journeys.sort((a, b) {
      DateTime departureA = a.legs.first.departureDateTime;
      DateTime departureB = b.legs.first.departureDateTime;

      return departureA.compareTo(departureB);
    });

    return journeys;
  }

  // Alternative sorting by planned departure time (if you need original schedule order)
  static List<Journey> parseAndSortByPlanned(List<dynamic> jsonJourneys) {
    List<Journey> journeys = jsonJourneys
        .map((json) => Journey.fromJson(json))
        .toList();

    journeys.sort((a, b) {
      DateTime plannedDepartureA = a.legs.first.plannedDepartureDateTime;
      DateTime plannedDepartureB = b.legs.first.plannedDepartureDateTime;

      return plannedDepartureA.compareTo(plannedDepartureB);
    });

    return journeys;
  }

  // Helper getters for convenience
  DateTime get departureTime => legs.first.departureDateTime;
  DateTime get arrivalTime => legs.last.arrivalDateTime;
  DateTime get plannedDepartureTime => legs.first.plannedDepartureDateTime;
  DateTime get plannedArrivalTime => legs.last.plannedArrivalDateTime;
}