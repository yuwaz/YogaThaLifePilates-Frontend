import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/dismiss_keyboard.dart';

void main() {
  testWidgets('DismissKeyboard unfocuses text field on outside tap', (
    tester,
  ) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DismissKeyboard(
            child: Column(
              children: [
                TextField(focusNode: focusNode),
                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );

    // Focus the text field (keyboard opens).
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    // Tap outside the field (empty area below, via coordinates).
    await tester.tapAt(const Offset(400, 500));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('DismissKeyboard does not block child gestures', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DismissKeyboard(
            child: Center(
              child: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('Tap me'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('DismissKeyboard works with numeric keyboard fields', (
    tester,
  ) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DismissKeyboard(
            child: Column(
              children: [
                TextField(
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(400, 500));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });
}
