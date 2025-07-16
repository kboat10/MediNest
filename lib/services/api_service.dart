import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://api.fda.gov';
  static const String _healthTipsUrl = 'https://api.adviceslip.com/advice';
  
  // Health Tips API
  static Future<String> getHealthTip({int? seed}) async {
    try {
      final tips = [
        'Take your medications at the same time every day for best results.',
        'Stay hydrated: drink at least 8 cups of water daily.',
        'Exercise regularly to boost your immune system.',
        'Wash your hands frequently to prevent illness.',
        'Eat a balanced diet rich in fruits and vegetables.',
        'Get at least 7-8 hours of sleep each night.',
        'Manage stress with relaxation techniques like deep breathing.',
        'Keep a medication log to track your doses and avoid missed medications.',
        'Schedule regular check-ups with your healthcare provider.',
        'Limit your intake of processed foods and sugary drinks.',
        'Take breaks from screens to reduce eye strain.',
        'Practice safe sun exposure and use sunscreen.',
        'Monitor your blood pressure regularly if you have hypertension.',
        'Don’t skip breakfast – it helps maintain energy levels.',
        'If you feel unwell, consult your doctor before self-medicating.',
      ];
      int index;
      if (seed != null) {
        index = seed % tips.length;
      } else {
        final now = DateTime.now();
        final startOfYear = DateTime(now.year, 1, 1);
        final dayOfYear = now.difference(startOfYear).inDays;
        index = dayOfYear % tips.length;
      }
      return tips[index];
    } catch (e) {
      return 'Take your medications at the same time every day for best results!';
    }
  }

  // Drug Information API (FDA)
  static Future<Map<String, dynamic>?> getDrugInfo(String drugName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/drug/label.json?search=generic_name:$drugName&limit=1'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final drug = results.first;
          return {
            'name': drug['openfda']?['generic_name']?.first ?? drugName,
            'brand_name': drug['openfda']?['brand_name']?.first ?? '',
            'description': drug['description']?.first ?? '',
            'indications': drug['indications_and_usage']?.first ?? '',
            'warnings': drug['warnings']?.first ?? '',
            'dosage': drug['dosage_and_administration']?.first ?? '',
            'side_effects': drug['adverse_reactions']?.first ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Drug Interactions API
  static Future<List<Map<String, dynamic>>> getDrugInteractions(List<String> drugNames) async {
    try {
      final interactions = <Map<String, dynamic>>[];
      
      for (int i = 0; i < drugNames.length; i++) {
        for (int j = i + 1; j < drugNames.length; j++) {
          final drug1 = drugNames[i];
          final drug2 = drugNames[j];
          
          // Simulate API call for drug interactions
          // In a real app, you would use a proper drug interaction API
          final interaction = await _simulateDrugInteraction(drug1, drug2);
          if (interaction != null) {
            interactions.add(interaction);
          }
        }
      }
      
      return interactions;
    } catch (e) {
      return [];
    }
  }

  // Simulate drug interaction check (replace with real API)
  static Future<Map<String, dynamic>?> _simulateDrugInteraction(String drug1, String drug2) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock interaction data
    final interactions = {
      'aspirin': {
        'ibuprofen': {
          'severity': 'moderate',
          'description': 'Taking aspirin with ibuprofen may reduce the effectiveness of aspirin.',
          'recommendation': 'Take at least 8 hours apart.',
        },
        'warfarin': {
          'severity': 'major',
          'description': 'Aspirin may increase the risk of bleeding when taken with warfarin.',
          'recommendation': 'Avoid combination unless directed by doctor.',
        },
      },
      'acetaminophen': {
        'alcohol': {
          'severity': 'major',
          'description': 'Combining acetaminophen with alcohol may cause liver damage.',
          'recommendation': 'Avoid alcohol while taking acetaminophen.',
        },
      },
    };
    
    final drug1Lower = drug1.toLowerCase();
    final drug2Lower = drug2.toLowerCase();
    
    if (interactions[drug1Lower]?[drug2Lower] != null) {
      return {
        'drug1': drug1,
        'drug2': drug2,
        ...interactions[drug1Lower]![drug2Lower]!,
      };
    }
    
    if (interactions[drug2Lower]?[drug1Lower] != null) {
      return {
        'drug1': drug2,
        'drug2': drug1,
        ...interactions[drug2Lower]![drug1Lower]!,
      };
    }
    
    // No known interaction
    return {
      'drug1': drug1,
      'drug2': drug2,
      'severity': 'none',
      'description': 'No known interaction found.',
      'recommendation': 'Continue as prescribed.',
    };
  }

  // Medication Reminders API (simulated)
  static Future<List<Map<String, dynamic>>> getMedicationReminders() async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Mock reminder data
      return [
        {
          'id': '1',
          'title': 'Medication Reminder',
          'message': 'Time to take your morning medication',
          'time': '08:00',
          'type': 'medication',
          'isActive': true,
        },
        {
          'id': '2',
          'title': 'Appointment Reminder',
          'message': 'You have a doctor appointment in 2 hours',
          'time': '14:00',
          'type': 'appointment',
          'isActive': true,
        },
        {
          'id': '3',
          'title': 'Refill Reminder',
          'message': 'Your prescription is running low',
          'time': '12:00',
          'type': 'refill',
          'isActive': true,
        },
      ];
    } catch (e) {
      return [];
    }
  }

  // Health News API
  static Future<List<Map<String, dynamic>>> getHealthNews() async {
    try {
      // Simulate API call for health news
      await Future.delayed(const Duration(milliseconds: 400));
      
      return [
        {
          'title': 'New Study Shows Benefits of Regular Exercise',
          'summary': 'Research indicates that 30 minutes of daily exercise can significantly improve heart health.',
          'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'source': 'Health Journal',
        },
        {
          'title': 'Importance of Medication Adherence',
          'summary': 'Taking medications as prescribed is crucial for treatment effectiveness.',
          'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'source': 'Medical News',
        },
        {
          'title': 'Tips for Better Sleep',
          'summary': 'Establishing a regular sleep schedule can improve overall health and well-being.',
          'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'source': 'Sleep Research',
        },
      ];
    } catch (e) {
      return [];
    }
  }

  // Symptom Checker API (simulated)
  static Future<List<Map<String, dynamic>>> getSymptomSuggestions(String symptom) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final suggestions = {
        'headache': [
          {'symptom': 'Tension Headache', 'severity': 'mild', 'suggestion': 'Rest in a quiet, dark room'},
          {'symptom': 'Migraine', 'severity': 'moderate', 'suggestion': 'Consider over-the-counter pain relievers'},
          {'symptom': 'Cluster Headache', 'severity': 'severe', 'suggestion': 'Seek medical attention immediately'},
        ],
        'fever': [
          {'symptom': 'Common Cold', 'severity': 'mild', 'suggestion': 'Rest and stay hydrated'},
          {'symptom': 'Flu', 'severity': 'moderate', 'suggestion': 'Consider antiviral medication'},
          {'symptom': 'Infection', 'severity': 'severe', 'suggestion': 'Seek medical attention'},
        ],
        'nausea': [
          {'symptom': 'Motion Sickness', 'severity': 'mild', 'suggestion': 'Try ginger or anti-nausea medication'},
          {'symptom': 'Food Poisoning', 'severity': 'moderate', 'suggestion': 'Stay hydrated and rest'},
          {'symptom': 'Severe Illness', 'severity': 'severe', 'suggestion': 'Seek medical attention'},
        ],
      };
      
      final symptomLower = symptom.toLowerCase();
      return suggestions[symptomLower] ?? [
        {'symptom': 'Unknown Symptom', 'severity': 'unknown', 'suggestion': 'Consult with a healthcare provider'},
      ];
    } catch (e) {
      return [];
    }
  }
} 