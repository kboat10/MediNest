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
    DateTime parsedDate;
    
    // Handle both Firestore Timestamp and regular DateTime string
    if (json['date'] is Timestamp) {
      parsedDate = (json['date'] as Timestamp).toDate();
    } else if (json['date'] is String) {
      parsedDate = DateTime.parse(json['date']);
    } else {
      parsedDate = DateTime.now(); // Fallback
    }
    
    return LogEntry(
      id: json['id'],
      date: parsedDate,
      description: json['description'],
      type: json['type'],
      feeling: json['feeling'],
      symptoms: json['symptoms'] != null ? List<String>.from(json['symptoms']) : null,
    );
  }

  Map<String, dynamic> toJson({bool forFirestore = false}) {
    return {
      'date': forFirestore ? Timestamp.fromDate(date) : date.toIso8601String(),
      'description': description,
      'type': type,
      'feeling': feeling,
      'symptoms': symptoms,
    };
  }
} 