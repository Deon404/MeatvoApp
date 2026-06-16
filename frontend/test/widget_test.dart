// Widget tests for Meatvo App
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/main.dart';

void main() {
  group('App Initialization', () {
    testWidgets('App should build without errors', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Pump frames to allow initialization to start
      await tester.pump();

      // Wait for splash screen timer and navigation (with timeout)
      // Splash screen has a 2 second timer, so we need to advance time
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(); // Allow navigation to complete

      // Verify that the app builds successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
