import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StealthService {
  static const MethodChannel _channel = MethodChannel('com.red.app/stealth');
  static const String _prefStealthEnabled = 'stealth_mode_enabled';
  static const String _prefStealthPin = 'stealth_pin_code';
  static const String defaultPin = '777';

  /// Check if stealth note app camouflage mode is enabled
  static Future<bool> isStealthModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefStealthEnabled) ?? false;
  }

  /// Get the secret 3-digit PIN code (defaults to '777')
  static Future<String> getSecretPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefStealthPin) ?? defaultPin;
  }

  /// Set the secret 3-digit PIN code
  static Future<void> setSecretPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStealthPin, pin.trim());
  }

  /// Toggle stealth mode on/off
  /// This switches the Android launcher icon & label dynamically and saves preference.
  static Future<bool> setStealthMode(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefStealthEnabled, enable);

    try {
      final result = await _channel.invokeMethod<bool>('setStealthLauncher', {
        'enabled': enable,
      });
      return result ?? true;
    } on PlatformException catch (e) {
      // Non-Android platforms or fallback
      return true;
    } catch (_) {
      return true;
    }
  }
}
