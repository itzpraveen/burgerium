import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

class BurgeriumHaptics {
  static Future<void> selection() async {
    await _play(
      duration: 55,
      amplitude: 180,
      fallback: HapticFeedback.selectionClick,
    );
  }

  static Future<void> soft() async {
    await _play(
      duration: 65,
      amplitude: 170,
      fallback: HapticFeedback.lightImpact,
    );
  }

  static Future<void> submit() async {
    await _play(
      duration: 100,
      amplitude: 220,
      fallback: HapticFeedback.mediumImpact,
    );
  }

  static Future<void> success() async {
    await _play(
      preset: VibrationPreset.quickSuccessAlert,
      duration: 90,
      amplitude: 180,
      fallback: HapticFeedback.mediumImpact,
    );
  }

  static Future<void> error() async {
    await _play(
      preset: VibrationPreset.doubleBuzz,
      duration: 120,
      amplitude: 220,
      fallback: HapticFeedback.heavyImpact,
    );
  }

  static Future<void> _play({
    required Future<void> Function() fallback,
    VibrationPreset? preset,
    required int duration,
    required int amplitude,
  }) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (preset != null && await Vibration.hasCustomVibrationsSupport()) {
          await Vibration.vibrate(preset: preset);
          return;
        }

        if (await Vibration.hasAmplitudeControl()) {
          await Vibration.vibrate(duration: duration, amplitude: amplitude);
          return;
        }

        await Vibration.vibrate(duration: duration);
        return;
      }
    } catch (_) {}

    try {
      await fallback();
    } catch (_) {}
  }
}
