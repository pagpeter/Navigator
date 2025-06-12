class DateAndTime 
{
  final int day;
  final int month;
  final int year;

  final int hour;
  final int minute;

  final int timeZoneHourShift;
  final int timeZoneMinuteShift;

  DateAndTime({
    required this.day,
    required this.month,
    required this.year,
    required this.hour,
    required this.minute,
    required this.timeZoneHourShift,
    required this.timeZoneMinuteShift
  });

    String ISO8601String() {
    String y = year.toString().padLeft(4, '0');
    String m = month.toString().padLeft(2, '0');
    String d = day.toString().padLeft(2, '0');
    String h = hour.toString().padLeft(2, '0');
    String min = minute.toString().padLeft(2, '0');

    String tzH = timeZoneHourShift.abs().toString().padLeft(2, '0');
    String tzM = timeZoneMinuteShift.toString().padLeft(2, '0');
    String tzSign = timeZoneHourShift >= 0 ? '+' : '-';

    return '$y-$m-$d'
           'T$h:$min'
           '$tzSign$tzH:$tzM';
  }

}