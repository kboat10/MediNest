class LogEntry {
  final DateTime date;
  final String description;
  final String type;
  final String? feeling;
  final List<String>? symptoms;

  LogEntry({
    required this.date,
    required this.description,
    required this.type,
    this.feeling,
    this.symptoms,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'type': type,
      'feeling': feeling,
      'symptoms': symptoms,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      feeling: json['feeling'],
      symptoms: (json['symptoms'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
} 