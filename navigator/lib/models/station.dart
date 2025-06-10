class Station {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

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
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
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

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
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