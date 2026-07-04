import 'package:flutter_test/flutter_test.dart';

import 'package:memento/main.dart';

void main() {
  testWidgets('MementoApp shows the empty-archive placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MementoApp());

    expect(find.text('Memento'), findsOneWidget);
    expect(find.text('Место, где мысли остаются навсегда.'), findsOneWidget);
  });
}
