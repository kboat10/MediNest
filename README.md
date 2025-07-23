# MediNest - Mobile Health Management App

A comprehensive Flutter mobile application designed to help users manage their medications, track health routines, and stay on top of medical appointments. Built as a semester examination project for Computer Science, this app addresses critical healthcare challenges by providing a personalized, user-friendly platform for medication adherence and health monitoring.

## 🎯 App Overview

MediNest is a personal health assistant that helps users:
- **Manage medications** with reminders and adherence tracking
- **Track health vitals** specific to their medical conditions
- **Log daily feelings and symptoms** for comprehensive health monitoring
- **Manage appointments** with notifications and scheduling
- **Export comprehensive health data** to PDF for healthcare providers
- **Access health education** through daily tips and condition-specific information
- **Use offline-first functionality** with cloud backup capabilities

## ✨ Key Features

### 🔐 Authentication & User Management
- **Firebase Authentication** - Secure sign up, sign in, and sign out
- **User Profile Management** - Personal details, health condition selection
- **Onboarding Flow** - Guided setup for new users with medication configuration
- **Session Management** - Persistent login with proper state handling

### 💊 Medication Management
- **Add/Edit/Delete Medications** - Complete medication lifecycle management
- **Smart Scheduling** - Set reminder times and frequency for each medication
- **Daily Adherence Tracking** - Mark medications as taken or missed
- **Streak Analytics** - Track current and longest medication adherence streaks
- **Medication History** - Comprehensive logging and analytics

### 🩺 Health Tracking & Monitoring
- **Condition-Specific Vitals** - Track blood pressure, blood sugar, peak flow based on health condition
- **Pain Level Monitoring** - Visual slider for pain tracking (especially for sickle cell and chronic pain)
- **Daily Feelings & Symptoms** - Log mood, symptoms, and health activities
- **Water Intake Tracking** - Hydration reminders and logging
- **Comprehensive Health Summary** - Daily dashboard with all health metrics

### 📅 Appointment Management
- **Add/Edit/Delete Appointments** - Complete appointment lifecycle
- **Smart Notifications** - 1-hour advance appointment reminders
- **Past & Future Views** - Organized appointment history and upcoming appointments
- **Location & Notes** - Detailed appointment information

### 🔔 Notifications & Reminders
- **Local Notifications** - Medication reminders and appointment alerts
- **Permission Handling** - Proper notification permission management
- **Test Functionality** - Built-in notification testing
- **Toggle Controls** - Enable/disable notifications as needed

### 📊 Data Management & Export
- **PDF Export** - Comprehensive health data export including medications, appointments, logs, and vitals
- **Local Backup & Restore** - Complete data backup and restoration
- **Cloud Sync** - Firebase integration with offline-first approach
- **Data Diagnostics** - Built-in tools for troubleshooting and debugging
- **Project Report Generation** - Automated PDF report creation for academic submission

### 🎨 User Interface & Experience
- **Dark Mode Support** - Automatic theme switching with manual override
- **Responsive Design** - Optimized for various screen sizes and orientations
- **Loading States** - Proper feedback during data operations
- **Error Handling** - Comprehensive error management with user-friendly messages
- **Accessibility** - Touch-friendly interface with proper contrast and readability

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point with provider setup
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── medication.dart       # Medication data structure
│   ├── appointment.dart      # Appointment data structure
│   ├── log_entry.dart        # Health log entries
│   └── user_profile.dart     # User profile data
├── screens/                  # UI screens
│   ├── auth_screen.dart      # Login/Signup interface
│   ├── onboarding_screen.dart # User setup and medication configuration
│   ├── home_screen.dart      # Dashboard with health summary
│   ├── schedule_screen.dart  # Medication management and scheduling
│   ├── logs_screen.dart      # Daily health tracking and vitals monitoring
│   ├── appointments_screen.dart # Medical appointment management
│   ├── health_tips_screen.dart # Health education and daily tips
│   ├── profile_screen.dart   # User profile and settings
│   ├── settings_screen.dart  # App configuration and preferences
│   └── data_management_screen.dart # Backup, restore, and export
├── providers/                # State management
│   ├── health_data_provider.dart # Main data provider
│   └── user_preferences_provider.dart # User preferences and theme
├── services/                 # Business logic and external services
│   ├── auth_service.dart     # Firebase authentication
│   ├── firestore_service.dart # Cloud database operations
│   ├── notification_service.dart # Local notifications
│   ├── shared_prefs_service.dart # Local storage
│   └── api_service.dart      # External API calls
└── widgets/                  # Reusable UI components
    ├── auth_wrapper.dart     # Authentication flow management
    ├── dashboard_card.dart   # Dashboard card components
    └── loading_widget.dart   # Loading indicators
```

## 📦 Dependencies & Packages

### Core Flutter Packages
- **provider** - State management across the app
- **shared_preferences** - Local data persistence
- **intl** - Date and time formatting

### Firebase Integration
- **firebase_core** - Firebase initialization
- **firebase_auth** - User authentication
- **cloud_firestore** - Cloud database (with offline persistence)

### UI & User Experience
- **flutter_local_notifications** - Local notification system
- **permission_handler** - Permission management
- **file_picker** - File selection and handling

### Data Export & Sharing
- **pdf** - PDF generation
- **printing** - PDF printing and sharing
- **share_plus** - File sharing capabilities

### Platform Support
- **android/** - Android-specific configurations
- **ios/** - iOS-specific configurations
- **web/** - Web platform support
- **macos/**, **windows/**, **linux/** - Desktop platform support

## 🚀 Getting Started

### Prerequisites
- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable version)
- [Dart](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- Firebase project setup (for authentication and cloud features)

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/kboat10/MediNest.git
   cd MediNest
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup** (Required for authentication)
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add Android and iOS apps to your Firebase project
   - Download and add the configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS
   - Enable Authentication and Firestore in Firebase Console

4. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Ensure Android SDK is properly configured
- Add `google-services.json` to `android/app/`
- Configure signing for release builds

#### iOS
- Ensure Xcode is installed and configured
- Add `GoogleService-Info.plist` to iOS project
- Configure signing and capabilities

#### Web
- No additional setup required
- Run with `flutter run -d chrome`

## 🧪 Testing

Run the test suite:
```bash
flutter test
```

Run specific test files:
```bash
flutter test test/widget_test.dart
```

## 📱 App Screenshots

The app contains 10 comprehensive screens:
1. **Auth Screen** - Login/Signup interface
2. **Onboarding Screen** - User setup and medication configuration
3. **Home Screen** - Dashboard with health summary
4. **Schedule Screen** - Medication management and scheduling
5. **Logs Screen** - Daily health tracking and vitals monitoring
6. **Appointments Screen** - Medical appointment management
7. **Health Tips Screen** - Health education and daily tips
8. **Profile Screen** - User profile and settings
9. **Settings Screen** - App configuration and preferences
10. **Data Management Screen** - Backup, restore, and export

## 🔧 Development Challenges & Solutions

### Firebase Integration Issues
- **Challenge**: Firestore connectivity problems causing timeouts and hanging operations
- **Solution**: Implemented offline-first approach with SharedPreferences as fallback, manual cloud sync functionality

### State Management Complexity
- **Challenge**: Managing complex state across multiple screens and providers
- **Solution**: Organized providers properly, implemented proper notifyListeners() calls, and used Consumer widgets for reactive UI

### Data Persistence Problems
- **Challenge**: User data not persisting between app sessions
- **Solution**: Comprehensive SharedPreferences implementation with proper serialization and error handling

### UI Update Issues
- **Challenge**: Medication status changes not reflecting in UI
- **Solution**: Wrapped UI components in Consumer widgets and ensured proper state management

### PDF Export Functionality
- **Challenge**: Creating comprehensive PDF reports with all health data
- **Solution**: Enhanced PDF generation to include medications, appointments, logs, vitals, and analytics

## 🎓 Academic Project Information

This project was developed as part of the **Semester Examination – Mini Project** for **Computer Science** at Ashesi University.

### Project Requirements Met
- ✅ **Flutter & Dart Development** - Complete mobile application
- ✅ **Health Sector Focus** - Addresses critical healthcare challenges
- ✅ **Real-world Problem Solving** - Medication adherence and health monitoring
- ✅ **Comprehensive Features** - Authentication, data management, notifications, export
- ✅ **Professional Documentation** - Complete README and project report
- ✅ **Git Version Control** - Proper repository management
- ✅ **Multi-platform Support** - Android, iOS, Web, Desktop platforms

## 📄 Project Report

A comprehensive project report is available as `project_report.html` containing:
- App description and objectives
- Complete feature list
- Screenshots and widget tree diagrams
- Detailed lessons learned and challenges faced
- Technical implementation details

## 🤝 Contributing

This is an academic project, but suggestions and feedback are welcome. Please feel free to:
- Report bugs or issues
- Suggest new features
- Improve documentation
- Share your experience using the app

## 📞 Contact Information

**Developer:** Nana Kwaku Afriyie Ampadu-Boateng  
**Course:** Computer Science  
**Email:** kwabaoat048@gmail.com  
**Phone:** +233551127363  
**GitHub:** [kboat10](https://github.com/kboat10)

## 📄 License

This project is developed for academic purposes as part of the Flutter Mobile Application Development course.

---

**MediNest** - Empowering users to take control of their health journey through intelligent medication management and comprehensive health tracking. 💊❤️

