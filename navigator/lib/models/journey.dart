import 'package:navigator/models/leg.dart';

class Journey {
  final List<Leg> legs;
  final String refreshToken;


  Journey({
    required this.legs,
    required this.refreshToken,

  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      legs: (json['legs'] as List)
          .map((legJson) => Leg.fromJson(legJson))
          .toList(),
      refreshToken: json['refreshToken'] ?? '', // Extract it safely
    );
  }

  static Journey parseSingleJourneyResponse(Map<String, dynamic> json) {
    if (!json.containsKey('legs')) {
      throw FormatException('Missing legs in single journey response');
    }
    return Journey.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'legs': legs.map((leg) => leg.toJson()).toList(),
      'refreshToken': refreshToken,
    };
  }

  static List<Journey> parseAndSort(List<dynamic> jsonJourneys) {
    List<Journey> journeys = jsonJourneys
        .map((json) {
      final journey = Journey.fromJson(json);
      print('Parsed Journey with refreshToken: ${journey.refreshToken}');
      return journey;
    })
        .toList();

    journeys.sort((a, b) {
      DateTime departureA = a.legs.first.departureDateTime;
      DateTime departureB = b.legs.first.departureDateTime;
      return departureA.compareTo(departureB);
    });

    return journeys;
  }

  static List<Journey> parseAndSortByPlanned(List<dynamic> jsonJourneys) {
    List<Journey> journeys = jsonJourneys
        .map((json) {
      final journey = Journey.fromJson(json);
      print('Parsed Journey with refreshToken: ${journey.refreshToken}');
      return journey;
    })
        .toList();

    // Sort by actual arrival time of the last leg
    journeys.sort((a, b) {
      DateTime arrivalA = a.legs.last.arrivalDateTime;
      DateTime arrivalB = b.legs.last.arrivalDateTime;
      return arrivalA.compareTo(arrivalB);
    });

    return journeys;
  }



  DateTime get departureTime => legs.first.departureDateTime;
  DateTime get arrivalTime => legs.last.arrivalDateTime;
  DateTime get plannedDepartureTime => legs.first.plannedDepartureDateTime;
  DateTime get plannedArrivalTime => legs.last.plannedArrivalDateTime;
}
