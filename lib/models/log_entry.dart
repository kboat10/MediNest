class LogEntry {
  final DateTime date;
  final String description;
  final String type;

  LogEntry({
    required this.date,
    required this.description,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'type': type,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      type: json['type'] ?? '',
    );
  }
} 