import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DramaFeaturePreferences {
  DramaFeaturePreferences._();

  static final instance = DramaFeaturePreferences._();
  static const _key = 'drama_feature_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier(true);
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      enabled.value = preferences.getBool(_key) ?? true;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> setEnabled(bool value) async {
    await load();
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_key, value)) {
      throw StateError('Could not save short drama preference');
    }
    enabled.value = value;
  }
}
