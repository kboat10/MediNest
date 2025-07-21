import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  final String? id; // For Firestore document ID
  final DateTime date;
  final String description;
  final String type;
  final String? feeling;
  final List<String>? symptoms;

  LogEntry({
    this.id,
    required this.date,
    required this.description,
    required this.type,
    this.feeling,
    this.symptoms,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'],
      date: (json['date'] as Timestamp).toDate(),
      description: json['description'],
      type: json['type'],
      feeling: json['feeling'],
      symptoms: json['symptoms'] != null ? List<String>.from(json['symptoms']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': Timestamp.fromDate(date),
      'description': description,
      'type': type,
      'feeling': feeling,
      'symptoms': symptoms,
    };
  }
} 