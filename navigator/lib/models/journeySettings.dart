class JourneySettings {
  bool? nationalExpress;
  bool? national;
  bool? regionalExpress;
  bool? regional;
  bool? suburban;
  bool? subway;
  bool? tram;
  bool? bus;
  bool? ferry;

  JourneySettings({
    this.nationalExpress = true,
    this.national = true,
    this.regionalExpress = true,
    this.regional = true,
    this.suburban = true,
    this.subway = true,
    this.tram = true,
    this.bus = true,
    this.ferry = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'nationalExpress': nationalExpress,
      'national': national,
      'regionalExpress': regionalExpress,
      'regional': regional,
      'suburban': suburban,
      'subway': subway,
      'tram': tram,
      'bus': bus,
      'ferry': ferry,
    };
  }
}
