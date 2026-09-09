import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _deviceIdPrefsKey = 'omega.deviceId';

/// A stable, random identifier for this app install, used to tell devices
/// apart for single-device login enforcement. It does not identify the
/// physical hardware (no device permissions needed) - only this install;
/// reinstalling the app produces a new one, which is the intended
/// behaviour (a fresh install is a "new device" as far as session
/// enforcement is concerned).
class DeviceIdService {
  DeviceIdService(this._prefs);

  final SharedPreferences _prefs;

  String getOrCreate() {
    final existing = _prefs.getString(_deviceIdPrefsKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generate();
    _prefs.setString(_deviceIdPrefsKey, generated);
    return generated;
  }

  static String _generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// The current device's id, or `null` while [sharedPreferencesProvider] is
/// still loading.
final deviceIdProvider = Provider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  if (prefs == null) return null;
  return DeviceIdService(prefs).getOrCreate();
});
