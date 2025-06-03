class Journey {
  final String id;
  final String departureStation;
  final String arrivalStation;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final List<String> trainNumbers;
  final bool isBooked;

  Journey({
    required this.id,
    required this.departureStation,
    required this.arrivalStation,
    required this.departureTime,
    required this.arrivalTime,
    required this.trainNumbers,
    required this.isBooked,
  });

  factory Journey.fromJson(Map<String, dynamic> json) => Journey(
        id: json['id'],
        departureStation: json['departureStation'],
        arrivalStation: json['arrivalStation'],
        departureTime: DateTime.parse(json['departureTime']),
        arrivalTime: DateTime.parse(json['arrivalTime']),
        trainNumbers: List<String>.from(json['trainNumbers']),
        isBooked: json['isBooked'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'departureStation': departureStation,
        'arrivalStation': arrivalStation,
        'departureTime': departureTime.toIso8601String(),
        'arrivalTime': arrivalTime.toIso8601String(),
        'trainNumbers': trainNumbers,
        'isBooked': isBooked,
      };
}