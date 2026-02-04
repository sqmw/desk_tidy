import 'package:flutter/widgets.dart';

class FrostStrengthScope extends InheritedNotifier<ValueNotifier<double>> {
  const FrostStrengthScope({
    super.key,
    required ValueNotifier<double> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static double strengthOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FrostStrengthScope>();
    final strength = scope?.notifier?.value ?? 1.0;
    return strength.clamp(0.0, 1.0);
  }
}
