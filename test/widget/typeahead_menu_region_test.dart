import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/core/widgets/typeahead_menu_region.dart';

void main() {
  testWidgets('multiple letters select the matching menu entry', (
    tester,
  ) async {
    var selected = 'Josua';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TypeaheadMenuRegion<String>(
              options: const ['Josua', 'Joel', 'Jona', 'Johannes'],
              labelFor: (value) => value,
              onSelected: (value) => setState(() => selected = value),
              builder: (context, typeahead) => PopupMenuButton<String>(
                key: const Key('book-menu'),
                onOpened: typeahead.open,
                onCanceled: typeahead.close,
                onSelected: (value) {
                  typeahead.close();
                  setState(() => selected = value);
                },
                itemBuilder: (context) => [
                  for (final value in const [
                    'Josua',
                    'Joel',
                    'Jona',
                    'Johannes',
                  ])
                    PopupMenuItem(value: value, child: Text(value)),
                ],
                child: Text(selected),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('book-menu')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    expect(selected, 'Johannes');
  });

  testWidgets('numbers combine and reset after the configured delay', (
    tester,
  ) async {
    var selected = 1;
    final values = List<int>.generate(20, (index) => index + 1);
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TypeaheadMenuRegion<int>(
              options: values,
              labelFor: (value) => '$value',
              onSelected: (value) => setState(() => selected = value),
              builder: (context, typeahead) => PopupMenuButton<int>(
                key: const Key('chapter-menu'),
                onOpened: typeahead.open,
                onCanceled: typeahead.close,
                onSelected: (value) {
                  typeahead.close();
                  setState(() => selected = value);
                },
                itemBuilder: (context) => [
                  for (final value in values)
                    PopupMenuItem(value: value, child: Text('$value')),
                ],
                child: Text('$selected'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('chapter-menu')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(selected, 12);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('chapter-menu')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(selected, 2);
  });
}
