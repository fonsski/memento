import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/presentation/home_screen.dart';

void main() {
  testWidgets('selecting a note replaces the empty-state content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
    );

    expect(find.text('О проекте'), findsOneWidget);

    await tester.tap(find.text('О проекте'));
    await tester.pumpAndSettle();

    expect(find.text('Место, где мысли остаются навсегда.'), findsNothing);
    expect(find.text('О проекте'), findsWidgets);
  });
}
