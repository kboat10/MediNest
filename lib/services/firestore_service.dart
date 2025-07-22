import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/log_entry.dart'; // Added import for LogEntry
import '../models/user_profile.dart'; // Added import for UserProfile

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // Add medication
  Future<DocumentReference> addMedication(Medication med, String uid) async {
    return await _db.collection('users').doc(uid).collection('medications').add(med.toJson());
  }

  // Update medication
  Future<void> updateMedication(String docId, Medication med) async {
    await _db.collection('users').doc(_uid).collection('medications').doc(docId).set(med.toJson());
  }

  // Delete medication
  Future<void> deleteMedication(String docId) async {
    await _db.collection('users').doc(_uid).collection('medications').doc(docId).delete();
  }

  // Fetch medications
  Stream<List<Map<String, dynamic>>> medicationsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // APPOINTMENT METHODS

  // Add appointment
  Future<DocumentReference> addAppointment(Appointment appointment, String uid) async {
    return await _db.collection('users').doc(uid).collection('appointments').add(appointment.toJson(forFirestore: true));
  }

  // Update appointment
  Future<void> updateAppointment(String docId, Appointment appointment, String uid) async {
    await _db.collection('users').doc(uid).collection('appointments').doc(docId).set(appointment.toJson(forFirestore: true));
  }

  // Delete appointment
  Future<void> deleteAppointment(String docId, String uid) async {
    await _db.collection('users').doc(uid).collection('appointments').doc(docId).delete();
  }

  // Fetch appointments stream
  Stream<List<Map<String, dynamic>>> appointmentsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('appointments')
        .orderBy('dateTime') // Sort by date
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()!}).toList());
  }

  // HEALTH LOG METHODS

  // Add log
  Future<DocumentReference> addLog(LogEntry log, String uid) async {
    return await _db.collection('users').doc(uid).collection('logs').add(log.toJson(forFirestore: true));
  }

  // Update log
  Future<void> updateLog(String docId, LogEntry log, String uid) async {
    await _db.collection('users').doc(uid).collection('logs').doc(docId).set(log.toJson(forFirestore: true));
  }

  // Delete log
  Future<void> deleteLog(String docId, String uid) async {
    await _db.collection('users').doc(uid).collection('logs').doc(docId).delete();
  }

  // Fetch logs stream
  Stream<List<Map<String, dynamic>>> logsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .orderBy('date', descending: true) // Sort by date, newest first
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()!}).toList());
  }

  // USER PROFILE METHODS

  // Set or update user profile
  Future<void> setUserProfile(UserProfile profile) async {
    await _db.collection('users').doc(profile.uid).set(profile.toJson());
  }

  // Get user profile stream
  Stream<UserProfile?> userProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromFirestore(doc.data()!, uid);
      }
      return null;
    });
  }

  // HEALTH DATA METHODS (Water Intake, Blood Pressure, etc.)

  // Save health data (water intake, blood pressure, blood sugar, peak flow)
  Future<void> saveHealthData(String uid, Map<String, dynamic> healthData) async {
    await _db.collection('users').doc(uid).collection('healthData').doc('vitals').set(healthData, SetOptions(merge: true));
  }

  // Get health data stream
  Stream<Map<String, dynamic>?> healthDataStream(String uid) {
    return _db.collection('users').doc(uid).collection('healthData').doc('vitals').snapshots().map((doc) {
      if (doc.exists) {
        return doc.data();
      }
      return null;
    });
  }
} 