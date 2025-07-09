class Remark {
  final String? text;
  final String? type;
  final String? code;
  final String? summary;
  final int? priority;

  Remark({
    this.text,
    this.type,
    this.code,
    this.summary,
    this.priority,
  });

  factory Remark.fromJson(Map<String, dynamic> json) {
    return Remark(
      text: json['text'] as String?,
      type: json['type'] as String?,
      code: json['code'] as String?,
      summary: json['summary'] as String?,
      priority: json['priority'] as int?,
    );
  }
}