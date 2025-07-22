import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String? id; // For Firestore document ID
  final String title;
  final DateTime dateTime;
  final String location;
  final String notes;

  Appointment({
    this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.notes,
  });
  
  // Update fromJson to accept 'id'
  factory Appointment.fromJson(Map<String, dynamic> json) {
    DateTime parsedDateTime;
    
    // Handle both Firestore Timestamp and regular DateTime string
    if (json['dateTime'] is Timestamp) {
      parsedDateTime = (json['dateTime'] as Timestamp).toDate();
    } else if (json['dateTime'] is String) {
      parsedDateTime = DateTime.parse(json['dateTime']);
    } else {
      parsedDateTime = DateTime.now(); // Fallback
    }
    
    return Appointment(
      id: json['id'],
      title: json['title'],
      dateTime: parsedDateTime,
      location: json['location'],
      notes: json['notes'],
    );
  }

  // Update toJson to exclude 'id'
  Map<String, dynamic> toJson({bool forFirestore = false}) {
    return {
      'title': title,
      'dateTime': forFirestore ? Timestamp.fromDate(dateTime) : dateTime.toIso8601String(),
      'location': location,
      'notes': notes,
    };
  }
} 