import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/presentation/markdown_syntax_controller.dart';

void main() {
  /// Flattens a [TextSpan] tree (as built by [buildTextSpan]) into its
  /// leaf (text, style) pairs, in order.
  List<(String, TextStyle?)> leaves(TextSpan span) {
    final List<(String, TextStyle?)> result = [];
    void visit(InlineSpan node) {
      if (node is TextSpan) {
        if (node.text != null && node.text!.isNotEmpty) {
          result.add((node.text!, node.style));
        }
        node.children?.forEach(visit);
      }
    }

    visit(span);
    return result;
  }

  TextSpan build(WidgetTester tester, String text) {
    final MarkdownSyntaxController controller = MarkdownSyntaxController(
      text: text,
    );
    addTearDown(controller.dispose);
    final BuildContext context = tester.element(find.byType(Placeholder));
    return controller.buildTextSpan(
      context: context,
      style: const TextStyle(color: Color(0xFF111111)),
      withComposing: false,
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
  }

  testWidgets('joining every leaf reproduces the original text', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    const String source = '# Заголовок\n**жир** и *курсив* и `код`';
    final TextSpan span = build(tester, source);

    expect(leaves(span).map((l) => l.$1).join(), source);
  });

  testWidgets('dims heading markers but not the heading text', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final TextSpan span = build(tester, '# Заголовок');
    final List<(String, TextStyle?)> parts = leaves(span);

    final TextStyle? markerStyle = parts.firstWhere((l) => l.$1 == '# ').$2;
    final TextStyle? headingStyle = parts
        .firstWhere((l) => l.$1 == 'Заголовок')
        .$2;

    expect(markerStyle?.color?.a, lessThan(1.0));
    expect(headingStyle?.color?.a, 1.0);
    expect(headingStyle?.fontSize, 28);
  });

  testWidgets('renders bold text with a bold weight and dims the markers', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final TextSpan span = build(tester, '**жирный**');
    final List<(String, TextStyle?)> parts = leaves(span);

    expect(
      parts.firstWhere((l) => l.$1 == 'жирный').$2?.fontWeight,
      FontWeight.w700,
    );
    expect(parts.firstWhere((l) => l.$1 == '**').$2?.color?.a, lessThan(1.0));
  });

  testWidgets('renders inline code in the monospace font', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final TextSpan span = build(tester, '`код`');
    final List<(String, TextStyle?)> parts = leaves(span);

    expect(
      parts.firstWhere((l) => l.$1 == 'код').$2?.fontFamily,
      'JetBrains Mono',
    );
  });
}
