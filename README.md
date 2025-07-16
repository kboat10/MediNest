# mymedbuddy

Hi! This is my coursework project for a health and medication manager app built with Flutter. I'm still learning, so this app was a great way to practice Flutter, state management, notifications, and more. The app is designed to help users manage their medications, track their health routines, and stay on top of appointments. Below, I describe what the app does, how it's structured, the packages I used, and some challenges I faced.

## App Overview
mymedbuddy is a personal health assistant app. It helps users:
- Add and manage their medications
- Set reminders for doses
- Log when they take or miss medications
- Track their medication streaks (how many days in a row they took all meds)
- Manage health appointments
- Get daily health tips
- Export their medication logs to PDF
- Use the app in both light and dark mode

The goal was to make medication management simple and to learn more about Flutter development.

## Features
- **Onboarding:**
  - When you first open the app, you’re guided through adding your medications and setting up reminders. You can add multiple medications, each with its own name, dosage, and reminder time.
- **Medication Schedule:**
  - Shows a list of all your medications and their scheduled times. You can add new medications, edit existing ones, or remove them. The schedule updates automatically if you change reminders.
- **Medication Logs:**
  - Every day, you see a checklist of your medications. You can mark each as taken or missed. If you miss a dose, the app will show a “Missed?” checkbox. This helps you keep track of your adherence.
- **Appointment Management:**
  - Add upcoming health appointments (doctor, pharmacy, etc.). The app will remind you 1 hour before each appointment. You can view, edit, or delete appointments from the appointments screen.
- **Health Tips:**
  - The dashboard displays a daily health tip from a curated list. You can tap “New Tip” to get a different random tip. Tips are meant to encourage healthy habits.
- **Notifications:**
  - The app uses local notifications to remind you to take your meds and to alert you before appointments. You can test notifications from the settings screen.
- **Medication Streaks:**
  - The dashboard shows how many consecutive days you’ve taken all your meds. This is meant to motivate you to stay consistent.
- **Dark Mode:**
  - The app supports both light and dark themes. It follows your device’s theme automatically.
- **Export Logs to PDF:**
  - You can export your medication logs as a PDF file for sharing with your doctor or for your own records. The PDF includes dates, medications, and whether each dose was taken or missed.

## Folder Structure (Main Parts)
- `lib/` – All Dart code (UI, logic, models, services)
  - `main.dart` – App entry point; sets up providers, themes, and routes.
  - `screens/` – Contains all main screens:
    - `dashboard_screen.dart` – Main dashboard with summary widgets
    - `schedule_screen.dart` – Medication schedule management
    - `logs_screen.dart` – Daily medication logs/checklist
    - `appointments_screen.dart` – Appointment management
    - `onboarding_screen.dart` – First-time setup
    - `settings_screen.dart` – App settings, notification test, etc.
  - `models/` – Data models:
    - `medication.dart`, `appointment.dart`, `log_entry.dart`, etc.
  - `services/` – App services:
    - `notification_service.dart` – Handles local notifications
    - `pdf_service.dart` – Handles PDF export
    - (others as needed)
  - `providers/` – State management:
    - `medication_provider.dart`, `logs_provider.dart`, `tips_provider.dart`, etc.
- `android/`, `ios/`, `macos/`, `windows/`, `linux/` – Platform-specific code for building/running on each OS.
- `test/` – Widget and unit tests for the app’s logic and UI.

## Packages Used
- `provider` – For state management across the app (medications, logs, tips, etc.). Makes it easy to update UI when data changes.
- `flutter_local_notifications` – To schedule and display local notifications for reminders and appointments.
- `permission_handler` – To request and check notification permissions from the user.
- `pdf` and `printing` – To generate and export medication logs as PDF files. `printing` also helps with sharing/printing the PDF.
- `shared_preferences` – For simple local storage of user data (medications, logs, settings).
- `intl` – For formatting dates and times in a user-friendly way.
- (and others, see `pubspec.yaml` for the full list)

## How to Run the App
1. Make sure you have [Flutter](https://flutter.dev/docs/get-started/install) installed and set up on your computer.
2. Clone this repo or download the code as a ZIP and extract it.
3. Open a terminal in the project folder and run:
   ```
   flutter pub get
   ```
   to install all dependencies.
4. Connect a device or start an emulator, then run:
   ```
   flutter run
   ```
5. The app may ask for notification permissions—please allow them so reminders work.
6. If you want to run tests, use:
   ```
   flutter test
   ```

**Troubleshooting:**
- If you get errors about missing packages, make sure you ran `flutter pub get`.
- If notifications don’t work, check your device’s notification settings and permissions.
- For PDF export, make sure your device/emulator supports file storage and sharing.

## Challenges I Faced
### Medication Streak Feature
I wanted to show how many days in a row the user took all their meds. The challenge was tracking streaks correctly, especially if the user missed a day or marked a med late. I had to compare log dates, check if all meds were taken each day, and reset the streak if any dose was missed. Handling edge cases (like missing logs for a day, or time zone changes) was tricky, and I had to test a lot to make sure the streak was accurate.

### Exporting Logs to PDF
Exporting logs to PDF was tricky because I had to format the data nicely and handle file permissions. I used the `pdf` and `printing` packages, but getting the layout right and making sure it worked on all platforms took some trial and error. I also had to figure out how to let users share or save the PDF, which was different on Android and iOS.

### Dark Mode
Adding dark mode was fun but a bit confusing at first. I had to define both light and dark themes and make sure all widgets used the right colors. Some custom widgets didn’t update automatically, so I had to tweak their styles and use Theme.of(context) in more places. Testing both modes helped me catch a few bugs where text was invisible or colors clashed.

---

## About the Author

**Name:** Nana Kwaku Afriyie Ampadu-Boateng  
**Course:** Computer Science  
**Emails:** kwabaoat048@gmail.com, nana.boateng@ashesi.edu.gh  
**Phone:** +233551127363

This project helped me learn a lot about Flutter and app development. If you have any questions or suggestions, feel free to reach out!

