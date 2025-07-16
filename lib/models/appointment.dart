class Appointment {
  final String title;
  final DateTime dateTime;
  final String location;
  final String notes;

  Appointment({
    required this.title,
    required this.dateTime,
    required this.location,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'notes': notes,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      title: json['title'] ?? '',
      dateTime: DateTime.parse(json['dateTime']),
      location: json['location'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
} 