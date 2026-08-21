import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moodify/main.dart';

void main() {
  testWidgets('App builds and shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoodifyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
  });
}