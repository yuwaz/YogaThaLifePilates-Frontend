import 'package:flutter/material.dart';

/// Dismisses the soft keyboard when the user taps outside a text field.
/// Wraps a page body so tapping any non-input area (including numeric/phone
/// keyboards, which have no return key) unfocuses the current field.
/// Uses HitTestBehavior.translucent so it never blocks child gestures.
class DismissKeyboard extends StatelessWidget {
  final Widget child;

  const DismissKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
