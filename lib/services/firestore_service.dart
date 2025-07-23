import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/log_entry.dart'; // Added import for LogEntry
import '../models/user_profile.dart'; // Added import for UserProfile

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirestoreService() {
    print('FirestoreService - Constructor called');
    print('FirestoreService - _db initialized: ${_db != null}');
    print('FirestoreService - _auth initialized: ${_auth != null}');
    
    // Test basic Firestore connectivity
    _testConnectivity();
  }
  
  Future<void> _testConnectivity() async {
    try {
      print('FirestoreService - Testing Firestore connectivity...');
      await _db.collection('test').doc('ping').get();
      print('FirestoreService - ✅ Firestore connectivity test PASSED');
    } catch (e) {
      print('FirestoreService - ❌ Firestore connectivity test FAILED: $e');
    }
  }

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
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
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
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // USER PROFILE METHODS

  // Set or update user profile
  Future<void> setUserProfile(UserProfile profile) async {
    print('FirestoreService - setUserProfile called for UID: ${profile.uid}');
    print('FirestoreService - About to call _db.collection');
    
    try {
      // Test basic connectivity first
      print('FirestoreService - Testing basic connectivity...');
      final testDoc = await _db.collection('test').doc('connectivity').get();
      print('FirestoreService - Basic connectivity test passed');
      
      // Test if we can read from the users collection
      print('FirestoreService - Testing read access to users collection...');
      final userDoc = await _db.collection('users').doc(profile.uid).get();
      print('FirestoreService - Read access test passed, document exists: ${userDoc.exists}');
      
      // Now try the write operation
      print('FirestoreService - Attempting write operation...');
      final profileData = profile.toJson();
      print('FirestoreService - Profile data to write: $profileData');
      
      await _db.collection('users').doc(profile.uid).set(profileData);
      print('FirestoreService - Successfully set user profile');
      
    } catch (e) {
      print('FirestoreService - Error in setUserProfile: $e');
      print('FirestoreService - Error type: ${e.runtimeType}');
      
      // Check if it's a permissions error
      if (e.toString().contains('permission-denied')) {
        print('FirestoreService - PERMISSION DENIED: Firestore security rules are blocking writes');
      }
      
      // Check if it's a network error
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        print('FirestoreService - NETWORK ERROR: Cannot reach Firebase servers');
      }
      
      // Check if it's a project configuration error
      if (e.toString().contains('project') || e.toString().contains('not-found')) {
        print('FirestoreService - PROJECT ERROR: Firebase project configuration issue');
      }
      
      throw e;
    }
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

  // Manual sync methods - Get data once (not streams)
  
  // Get medications once
  Future<List<Map<String, dynamic>>> getMedications(String uid) async {
    try {
      final snapshot = await _db.collection('users').doc(uid).collection('medications').get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('FirestoreService - Error getting medications: $e');
      return [];
    }
  }

  // Get appointments once
  Future<List<Map<String, dynamic>>> getAppointments(String uid) async {
    try {
      final snapshot = await _db.collection('users').doc(uid).collection('appointments').orderBy('dateTime').get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('FirestoreService - Error getting appointments: $e');
      return [];
    }
  }

  // Get logs once
  Future<List<Map<String, dynamic>>> getLogs(String uid) async {
    try {
      final snapshot = await _db.collection('users').doc(uid).collection('logs').orderBy('date', descending: true).get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('FirestoreService - Error getting logs: $e');
      return [];
    }
  }

  // Get health data once
  Future<Map<String, dynamic>?> getHealthData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).collection('healthData').doc('vitals').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('FirestoreService - Error getting health data: $e');
      return null;
    }
  }

  // Comprehensive test method to diagnose Firestore issues
  Future<Map<String, dynamic>> diagnoseFirestoreIssues() async {
    final results = <String, dynamic>{};
    
    try {
      print('FirestoreService - 🔍 Starting comprehensive Firestore diagnosis...');
      
      // Test 1: Basic connectivity
      print('FirestoreService - Test 1: Basic connectivity...');
      try {
        await _db.collection('test').doc('diagnosis').get();
        results['connectivity'] = 'PASS';
        print('FirestoreService - ✅ Basic connectivity: PASS');
      } catch (e) {
        results['connectivity'] = 'FAIL: $e';
        print('FirestoreService - ❌ Basic connectivity: FAIL - $e');
      }
      
      // Test 2: Authentication state
      print('FirestoreService - Test 2: Authentication state...');
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        results['authentication'] = 'PASS: ${currentUser.email}';
        print('FirestoreService - ✅ Authentication: PASS - ${currentUser.email}');
      } else {
        results['authentication'] = 'FAIL: No authenticated user';
        print('FirestoreService - ❌ Authentication: FAIL - No authenticated user');
      }
      
      // Test 3: Read access to users collection
      print('FirestoreService - Test 3: Read access to users collection...');
      try {
        if (currentUser != null) {
          await _db.collection('users').doc(currentUser.uid).get();
          results['read_access'] = 'PASS';
          print('FirestoreService - ✅ Read access: PASS');
        } else {
          results['read_access'] = 'SKIP: No authenticated user';
          print('FirestoreService - ⚠️ Read access: SKIP - No authenticated user');
        }
      } catch (e) {
        results['read_access'] = 'FAIL: $e';
        print('FirestoreService - ❌ Read access: FAIL - $e');
      }
      
      // Test 4: Write access to users collection
      print('FirestoreService - Test 4: Write access to users collection...');
      try {
        if (currentUser != null) {
          await _db.collection('users').doc(currentUser.uid).set({
            'test': true,
            'timestamp': FieldValue.serverTimestamp(),
          });
          results['write_access'] = 'PASS';
          print('FirestoreService - ✅ Write access: PASS');
        } else {
          results['write_access'] = 'SKIP: No authenticated user';
          print('FirestoreService - ⚠️ Write access: SKIP - No authenticated user');
        }
      } catch (e) {
        results['write_access'] = 'FAIL: $e';
        print('FirestoreService - ❌ Write access: FAIL - $e');
      }
      
      // Test 5: Network connectivity
      print('FirestoreService - Test 5: Network connectivity...');
      try {
        final testDoc = await _db.collection('test').doc('network').get();
        results['network'] = 'PASS';
        print('FirestoreService - ✅ Network connectivity: PASS');
      } catch (e) {
        results['network'] = 'FAIL: $e';
        print('FirestoreService - ❌ Network connectivity: FAIL - $e');
      }
      
      // Test 6: Firestore settings
      print('FirestoreService - Test 6: Firestore settings...');
      try {
        final settings = _db.settings;
        results['settings'] = {
          'persistenceEnabled': settings.persistenceEnabled ?? false,
          'cacheSizeBytes': settings.cacheSizeBytes,
          'host': settings.host ?? 'default',
        };
        final persistenceStatus = (settings.persistenceEnabled ?? false) ? 'PERSISTENCE ENABLED' : 'PERSISTENCE DISABLED';
        print('FirestoreService - ✅ Settings: $persistenceStatus');
      } catch (e) {
        results['settings'] = 'FAIL: $e';
        print('FirestoreService - ❌ Settings: FAIL - $e');
      }
      
      print('FirestoreService - 🔍 Firestore diagnosis completed');
      return results;
      
    } catch (e) {
      print('FirestoreService - ❌ Diagnosis failed: $e');
      return {'error': e.toString()};
    }
  }

  // Method to test specific Firestore operations
  Future<Map<String, dynamic>> testFirestoreOperations() async {
    final results = <String, dynamic>{};
    final currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      return {'error': 'No authenticated user'};
    }
    
    try {
      print('FirestoreService - 🧪 Testing specific Firestore operations...');
      
      // Test 1: Create a test document
      print('FirestoreService - Test 1: Creating test document...');
      try {
        final docRef = await _db.collection('test').add({
          'test': true,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': currentUser.uid,
        });
        results['create_document'] = 'PASS: ${docRef.id}';
        print('FirestoreService - ✅ Create document: PASS');
        
        // Test 2: Read the test document
        print('FirestoreService - Test 2: Reading test document...');
        final doc = await docRef.get();
        if (doc.exists) {
          results['read_document'] = 'PASS';
          print('FirestoreService - ✅ Read document: PASS');
        } else {
          results['read_document'] = 'FAIL: Document does not exist';
          print('FirestoreService - ❌ Read document: FAIL - Document does not exist');
        }
        
        // Test 3: Update the test document
        print('FirestoreService - Test 3: Updating test document...');
        await docRef.update({
          'updated': true,
          'updateTimestamp': FieldValue.serverTimestamp(),
        });
        results['update_document'] = 'PASS';
        print('FirestoreService - ✅ Update document: PASS');
        
        // Test 4: Delete the test document
        print('FirestoreService - Test 4: Deleting test document...');
        await docRef.delete();
        results['delete_document'] = 'PASS';
        print('FirestoreService - ✅ Delete document: PASS');
        
      } catch (e) {
        results['operations'] = 'FAIL: $e';
        print('FirestoreService - ❌ Operations: FAIL - $e');
      }
      
      return results;
      
    } catch (e) {
      print('FirestoreService - ❌ Operation tests failed: $e');
      return {'error': e.toString()};
    }
  }
} 