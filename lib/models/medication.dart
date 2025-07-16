class Medication {
  final String name;
  final String time;
  final bool taken;
  final String? reminderTime;

  Medication({
    required this.name,
    required this.time,
    this.taken = false,
    this.reminderTime,
  });

  Medication copyWith({
    String? name,
    String? time,
    bool? taken,
    String? reminderTime,
  }) {
    return Medication(
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
      name: json['name'] ?? '',
      time: json['time'] ?? '',
      taken: json['taken'] ?? false,
      reminderTime: json['reminderTime'],
    );
  }
} 