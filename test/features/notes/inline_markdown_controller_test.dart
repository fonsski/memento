import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/presentation/inline_markdown_controller.dart';

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

  TextSpan build(WidgetTester tester, String text, {TextStyle? style}) {
    final InlineMarkdownController controller = InlineMarkdownController(
      text: text,
    );
    addTearDown(controller.dispose);
    final BuildContext context = tester.element(find.byType(Placeholder));
    return controller.buildTextSpan(
      context: context,
      style: style ?? const TextStyle(color: Color(0xFF111111), fontSize: 20),
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
    const String source = '**жир** и *курсив* и `код`';
    final TextSpan span = build(tester, source);

    expect(leaves(span).map((l) => l.$1).join(), source);
  });

  testWidgets('dims markers relative to the surrounding style', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final TextSpan span = build(tester, '**жир**');
    final List<(String, TextStyle?)> parts = leaves(span);

    final TextStyle? markerStyle = parts.firstWhere((l) => l.$1 == '**').$2;
    final TextStyle? boldStyle = parts.firstWhere((l) => l.$1 == 'жир').$2;

    expect(markerStyle?.color?.a, lessThan(1.0));
    expect(markerStyle?.fontSize, lessThan(20));
    expect(boldStyle?.color?.a, 1.0);
    expect(boldStyle?.fontWeight, FontWeight.w700);
  });

  testWidgets('inherits the ambient style rather than a fixed size', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final TextSpan span = build(
      tester,
      'обычный',
      style: const TextStyle(fontSize: 28, color: Color(0xFF000000)),
    );

    expect(leaves(span).single.$2?.fontSize, 28);
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

  testWidgets('renders italic text with an italic font style', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final TextSpan span = build(tester, '*курсив*');
    final List<(String, TextStyle?)> parts = leaves(span);

    expect(
      parts.firstWhere((l) => l.$1 == 'курсив').$2?.fontStyle,
      FontStyle.italic,
    );
  });
}
