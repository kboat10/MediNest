// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medinest/main.dart';

void main() {
  testWidgets('Home screen displays Health Tips card', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(); // Wait for all animations and async work

    // Look for the Health Tips card by its text
    expect(find.text('Health Tips'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb), findsWidgets); // Icon is present
    // Optionally, check the subtitle text
    expect(find.textContaining('Get daily health tips'), findsOneWidget);
  });
}
