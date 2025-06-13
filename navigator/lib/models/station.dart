import 'package:navigator/models/location.dart';

class Station extends Location{
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
    required this.taxi
  });

  factory Station.empty()
  {
    return Station(bus: false, ferry: false, id: '', latitude: 0, longitude: 0, name: '', national: false, nationalExpress: false, regional: false, regionalExpress: false, suburban: false, subway: false, taxi: false, tram: false, type: '');
  }

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      type: json['type'],
      id: json['id'],
      name: json['name'],
      latitude: json['location']['latitude'],
      longitude: json['location']['longitude'],
      nationalExpress: json['products']['nationalExpress'],
      national: json['products']['national'],
      regional: json['products']['regional'],
      regionalExpress: json['products']['regionalExpress'],
      suburban: json['products']['suburban'],
      bus: json['products']['bus'],
      ferry: json['products']['ferry'],
      subway: json['products']['subway'],
      tram: json['products']['tram'],
      taxi: json['products']['taxi']
    );
  }
}