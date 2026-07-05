import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/core/theme/custom_theme.dart';
import 'package:memento/core/theme/theme_picker_dialog.dart';

void main() {
  // CustomThemeRepository.create() goes through path_provider, which has
  // no platform implementation registered under flutter_test. That
  // MethodChannel call still needs the real event loop to resolve (even
  // to fail), which testWidgets() otherwise fakes — so triggering it and
  // waiting for the result needs tester.runAsync(), the same as real
  // dart:io work. This exercises the dialog's "couldn't load custom
  // themes, but the built-in option still works" path; custom theme
  // *listing* itself is covered by CustomThemeRepository's own tests.
  Widget wrap(WidgetBuilder builder) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Builder(builder: builder),
    );
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maxTries = 50,
  }) async {
    for (int i = 0; i < maxTries; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      if (condition()) return;
    }
    if (!condition()) {
      throw StateError('Condition not met after ${maxTries * 50}ms');
    }
  }

  testWidgets('shows the built-in option even when the folder scan fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () => showThemePicker(context, currentThemeId: null),
          child: const Text('open'),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('open'));
      await pumpUntil(
        tester,
        () => find
            .text('Не удалось загрузить пользовательские темы')
            .evaluate()
            .isNotEmpty,
      );
    });
    await tester.pump();

    expect(find.text('Встроенная (Ink & Patina)'), findsOneWidget);
    expect(
      find.text('Не удалось загрузить пользовательские темы'),
      findsOneWidget,
    );
  });

  testWidgets('choosing the built-in option resolves (null, null)', (
    WidgetTester tester,
  ) async {
    (String?, CustomThemeDefinition?)? result;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await showThemePicker(context, currentThemeId: null);
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('open'));
      await pumpUntil(
        tester,
        () => find.text('Встроенная (Ink & Patina)').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Встроенная (Ink & Patina)'));
      await pumpUntil(tester, () => result != null);
    });
    await tester.pump();

    expect(result, (null, null));
  });

  testWidgets('closing without a choice resolves null', (
    WidgetTester tester,
  ) async {
    Object? result = 'unset';
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await showThemePicker(context, currentThemeId: null);
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('open'));
      await pumpUntil(tester, () => find.text('Закрыть').evaluate().isNotEmpty);
      await tester.tap(find.text('Закрыть'));
      await pumpUntil(tester, () => result == null);
    });
    await tester.pump();

    expect(result, isNull);
  });
}
