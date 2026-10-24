import 'package:flutter/services.dart';

/// Centralised haptic feedback so the feel is consistent app-wide.
class Haptics {
  Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.heavyImpact();
}
