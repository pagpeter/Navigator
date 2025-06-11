import 'package:navigator/models/station.dart';

class Leg 
{
  final String tripID;
  final String direction;
  final Station origin;
  final String departure;
  final String plannedDeparture;
  final String departureDelay;
  final String departurePlatform;
  final String plannedDeparturePlatform;
  final Station destination;
  final String arrival;
  final String plannedArrival;
  final String arrivalDelay;
  final String arrivalPlatform;
  final String plannedArrivalPlatform;

  Leg
  ({
    required this.tripID,
    required this.direction,
    required this.origin,
    required this.departure,
    required this.plannedDeparture,
    required this.departureDelay,
    required this.departurePlatform,
    required this.plannedDeparturePlatform,
    required this.destination,
    required this.arrival,
    required this.plannedArrival,
    required this.arrivalDelay,
    required this.arrivalPlatform,
    required this.plannedArrivalPlatform
  });

}