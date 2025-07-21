class Medication {
  final String? id; // For Firestore document ID
  final String name;
  final String time;
  final bool taken;
  final String? reminderTime;

  Medication({this.id, required this.name, required this.time, this.taken = false, this.reminderTime});

  Medication copyWith({
    String? id, // Add id here
    String? name,
    String? time,
    bool? taken,
    String? reminderTime,
  }) {
    return Medication(
      id: id ?? this.id, // Use new id or existing id
      name: name ?? this.name,
      time: time ?? this.time,
      taken: taken ?? this.taken,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time,
      'taken': taken,
      'reminderTime': reminderTime,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'] ?? '',
      time: json['time'] ?? '',
      taken: json['taken'] ?? false,
      reminderTime: json['reminderTime'],
    );
  }
} 