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
    return Appointment(
      id: json['id'],
      title: json['title'],
      dateTime: (json['dateTime'] as Timestamp).toDate(),
      location: json['location'],
      notes: json['notes'],
    );
  }

  // Update toJson to exclude 'id'
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'notes': notes,
    };
  }
} 