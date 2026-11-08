import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BiometricSetupResult { enabled, unavailable, canceled, failed }

class LocalBiometricLock extends ChangeNotifier {
  LocalBiometricLock({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;
  String? _userId;
  bool _enabled = false;
  bool _loaded = false;
  bool _enabledAfterAuthentication = false;

  String? get userId => _userId;
  bool get enabled => _enabled;
  bool get loaded => _loaded;

  String _key(String userId) => 'agro_local_biometric_lock_$userId';

  Future<void> loadForUser(String? userId) async {
    if (_userId == userId && _loaded) return;
    _userId = userId;
    _loaded = false;
    _enabled = false;
    _enabledAfterAuthentication = false;
    notifyListeners();
    if (userId != null) {
      final preferences = await SharedPreferences.getInstance();
      if (_userId == userId) {
        _enabled = preferences.getBool(_key(userId)) ?? false;
      }
    }
    if (_userId != userId) return;
    _loaded = true;
    notifyListeners();
  }

  Future<BiometricSetupResult> enableForUser(String userId) async {
    try {
      if (!await _authentication.isDeviceSupported()) {
        return BiometricSetupResult.unavailable;
      }
      final accepted = await _authentication.authenticate(
        localizedReason:
            'Desbloquea Agro+ para proteger el acceso a tu cuenta.',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!accepted) return BiometricSetupResult.canceled;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_key(userId), true);
      _userId = userId;
      _enabled = true;
      _loaded = true;
      _enabledAfterAuthentication = true;
      notifyListeners();
      return BiometricSetupResult.enabled;
    } catch (_) {
      return BiometricSetupResult.failed;
    }
  }

  Future<void> disableForUser(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId));
    if (_userId == userId) {
      _enabled = false;
      _enabledAfterAuthentication = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Confirma tu identidad para volver a Agro+.',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  bool consumeAuthenticatedEnable() {
    final wasJustEnabled = _enabledAfterAuthentication;
    _enabledAfterAuthentication = false;
    return wasJustEnabled;
  }
}
