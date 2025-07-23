import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class ReportGenerator {
  static Future<void> generateProjectReport() async {
    final pdf = pw.Document();
    
    // Add title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'MediNest - Mobile Health Management App',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Flutter Mobile Application Development Project',
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Text(
                'Semester Examination – Mini Project',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Deadline: 22nd July, 2025',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'Student Information:',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Name: Nana Kwaku Afriyie Ampadu-Boateng'),
            pw.Text('Course: Computer Science'),
            pw.Text('Email: kwabaoat048@gmail.com'),
            pw.Text('Phone: +233551127363'),
            pw.SizedBox(height: 30),
            pw.Text(
              'GitHub Repository: https://github.com/kboat10/MediNest.git',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blue,
              ),
            ),
          ],
        ),
      ),
    );

    // Add App Description page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '1. App Description',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'MediNest is a comprehensive mobile health management application designed to help users manage their medications, track health routines, and stay on top of medical appointments. The app addresses critical healthcare challenges by providing a personalized, user-friendly platform for medication adherence and health monitoring.',
              style: pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Key Objectives:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Bullet(
              text: 'Improve medication adherence through reminders and tracking',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Provide condition-specific health monitoring (hypertension, diabetes, asthma, sickle cell)',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Enable comprehensive health logging and symptom tracking',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Facilitate appointment management with notifications',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Offer health education through daily tips and condition-specific information',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Target Users:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '• Patients with chronic conditions requiring medication management\n'
              '• Individuals seeking to improve their health tracking habits\n'
              '• Healthcare providers who want to monitor patient adherence\n'
              '• Caregivers managing medication schedules for dependents',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Technology Stack:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '• Frontend: Flutter & Dart\n'
              '• Backend: Firebase (Authentication, Firestore)\n'
              '• Local Storage: SharedPreferences\n'
              '• State Management: Provider Pattern\n'
              '• Notifications: Flutter Local Notifications\n'
              '• PDF Generation: pdf & printing packages',
              style: pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );

    // Add Feature List page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '2. Feature List',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Authentication & User Management
            pw.Text(
              'Authentication & User Management:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Firebase Authentication (sign up, sign in, sign out)'),
            pw.Bullet(text: 'User profile management with health condition selection'),
            pw.Bullet(text: 'Onboarding flow for new users'),
            pw.Bullet(text: 'Secure data access and user session management'),
            pw.SizedBox(height: 10),
            
            // Medication Management
            pw.Text(
              'Medication Management:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Add, edit, delete medications with dosage information'),
            pw.Bullet(text: 'Set medication schedules and reminder times'),
            pw.Bullet(text: 'Daily medication adherence tracking (taken/missed)'),
            pw.Bullet(text: 'Medication streak tracking (current and longest streaks)'),
            pw.Bullet(text: 'Medication history and analytics'),
            pw.SizedBox(height: 10),
            
            // Health Tracking
            pw.Text(
              'Health Tracking & Monitoring:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Condition-specific vitals tracking (BP, blood sugar, peak flow)'),
            pw.Bullet(text: 'Pain level monitoring with visual slider'),
            pw.Bullet(text: 'Water intake tracking with hydration reminders'),
            pw.Bullet(text: 'Daily feelings and symptoms logging'),
            pw.Bullet(text: 'Comprehensive health summary dashboard'),
            pw.SizedBox(height: 10),
            
            // Appointment Management
            pw.Text(
              'Appointment Management:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Add, edit, delete medical appointments'),
            pw.Bullet(text: 'Appointment notifications (1 hour before)'),
            pw.Bullet(text: 'View past and upcoming appointments'),
            pw.Bullet(text: 'Appointment details with location and notes'),
            pw.SizedBox(height: 10),
            
            // Notifications
            pw.Text(
              'Notifications & Reminders:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Local notifications for medication reminders'),
            pw.Bullet(text: 'Appointment notifications'),
            pw.Bullet(text: 'Notification permissions handling'),
            pw.Bullet(text: 'Test notification functionality'),
            pw.Bullet(text: 'Toggle notifications on/off'),
            pw.SizedBox(height: 10),
            
            // Data Management
            pw.Text(
              'Data Management & Export:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'PDF export of comprehensive health data'),
            pw.Bullet(text: 'Local data backup and restore'),
            pw.Bullet(text: 'Cloud sync functionality (Firebase)'),
            pw.Bullet(text: 'Data management with diagnostics'),
            pw.Bullet(text: 'Offline-first functionality'),
            pw.SizedBox(height: 10),
            
            // User Interface
            pw.Text(
              'User Interface & Experience:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Dark mode support with theme switching'),
            pw.Bullet(text: 'Responsive design with proper navigation'),
            pw.Bullet(text: 'Loading states and error handling'),
            pw.Bullet(text: 'User-friendly forms and validation'),
            pw.Bullet(text: 'Health tips and educational content'),
          ],
        ),
      ),
    );

    // Add Screenshots page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '3. Screenshots',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'The app contains 10 comprehensive screens:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Text('1. Auth Screen - Login/Signup interface'),
            pw.Text('2. Onboarding Screen - User setup and medication configuration'),
            pw.Text('3. Home Screen - Dashboard with health summary'),
            pw.Text('4. Schedule Screen - Medication management and scheduling'),
            pw.Text('5. Logs Screen - Daily health tracking and vitals monitoring'),
            pw.Text('6. Appointments Screen - Medical appointment management'),
            pw.Text('7. Health Tips Screen - Health education and daily tips'),
            pw.Text('8. Profile Screen - User profile and settings'),
            pw.Text('9. Settings Screen - App configuration and preferences'),
            pw.Text('10. Data Management Screen - Backup, restore, and export'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Note: Screenshots would be included here showing the actual app interface, navigation flow, and key features in action.',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    // Add Widget Tree Diagrams page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '4. Widget Tree Diagram for Each Screen',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Home Screen Widget Tree
            pw.Text(
              'Home Screen Widget Tree:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Scaffold'),
            pw.Text('  ├── AppBar'),
            pw.Text('  ├── Consumer<HealthDataProvider>'),
            pw.Text('  │   └── Column'),
            pw.Text('  │       ├── Dashboard Cards (Grid)'),
            pw.Text('  │       │   ├── Medication Card'),
            pw.Text('  │       │   ├── Streak Card'),
            pw.Text('  │       │   ├── Appointments Card'),
            pw.Text('  │       │   └── Health Tips Card'),
            pw.Text('  │       └── Quick Actions'),
            pw.Text('  └── BottomNavigationBar'),
            pw.SizedBox(height: 15),
            
            // Logs Screen Widget Tree
            pw.Text(
              'Logs Screen Widget Tree:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Scaffold'),
            pw.Text('  ├── AppBar'),
            pw.Text('  ├── Consumer2<HealthDataProvider, UserPreferencesProvider>'),
            pw.Text('  │   └── Column'),
            pw.Text('  │       ├── Date Selector'),
            pw.Text('  │       ├── Health Input Forms'),
            pw.Text('  │       │   ├── Feelings & Symptoms'),
            pw.Text('  │       │   ├── Condition-specific Vitals'),
            pw.Text('  │       │   └── Pain Level Slider'),
            pw.Text('  │       ├── Medication Checklist'),
            pw.Text('  │       └── Daily Summary'),
            pw.SizedBox(height: 15),
            
            // Schedule Screen Widget Tree
            pw.Text(
              'Schedule Screen Widget Tree:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Scaffold'),
            pw.Text('  ├── AppBar'),
            pw.Text('  ├── Consumer<HealthDataProvider>'),
            pw.Text('  │   └── Column'),
            pw.Text('  │       ├── Add Medication Button'),
            pw.Text('  │       └── ListView.builder'),
            pw.Text('  │           └── Medication Cards'),
            pw.Text('  │               ├── Medication Info'),
            pw.Text('  │               ├── Schedule Details'),
            pw.Text('  │               └── Action Buttons'),
            pw.SizedBox(height: 15),
            
            // Appointments Screen Widget Tree
            pw.Text(
              'Appointments Screen Widget Tree:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Scaffold'),
            pw.Text('  ├── AppBar'),
            pw.Text('  ├── Consumer<HealthDataProvider>'),
            pw.Text('  │   └── Column'),
            pw.Text('  │       ├── Add Appointment Button'),
            pw.Text('  │       ├── TabBar (Upcoming/Past)'),
            pw.Text('  │       └── TabBarView'),
            pw.Text('  │           └── ListView.builder'),
            pw.Text('  │               └── Appointment Cards'),
            pw.Text('  │                   ├── Appointment Details'),
            pw.Text('  │                   └── Action Buttons'),
          ],
        ),
      ),
    );

    // Add Lessons Learned page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '5. Lessons Learned',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 20),
            
            pw.Text(
              'Technical Lessons:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Bullet(
              text: 'State Management: Learned the importance of proper state management using Provider pattern for complex applications',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Firebase Integration: Gained experience with Firebase Auth and Firestore for backend services',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Local Storage: Understood the balance between local and cloud storage for offline functionality',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Error Handling: Implemented comprehensive error handling for better user experience',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'PDF Generation: Learned to create complex PDF reports with proper formatting and data organization',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 15),
            
            pw.Text(
              'UI/UX Lessons:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Bullet(
              text: 'User Experience: Importance of intuitive navigation and clear information hierarchy',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Accessibility: Need for proper contrast, readable fonts, and touch-friendly interface elements',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Responsive Design: Adapting layouts for different screen sizes and orientations',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Loading States: Providing feedback during data loading and processing operations',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 15),
            
            pw.Text(
              'Project Management Lessons:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Bullet(
              text: 'Version Control: Importance of regular commits and proper Git workflow for collaborative development',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Code Organization: Benefits of proper folder structure and separation of concerns',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Documentation: Need for comprehensive documentation for maintainability and future development',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Testing: Importance of testing at different stages of development',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 15),
            
            pw.Text(
              'Domain Knowledge:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Bullet(
              text: 'Healthcare Apps: Understanding the sensitivity and importance of health data management',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'User Privacy: Implementing proper data protection and user consent mechanisms',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Medical Compliance: Awareness of healthcare regulations and best practices',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 15),
            
            pw.Text(
              'Future Improvements:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Bullet(
              text: 'Advanced Analytics: Implement more sophisticated health analytics and insights',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Integration: Connect with healthcare providers and electronic health records',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'AI Features: Add machine learning for personalized health recommendations',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.Bullet(
              text: 'Multi-platform: Extend to iOS and web platforms for broader accessibility',
              style: pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );

    // Save the PDF
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
} 