import 'package:hive_ce/hive_ce.dart';

class OnboardingStorageService {
  static const _boxName = 'focused_onboarding';
  static const _introSeenKey = 'auth_intro_seen_v1';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  bool get introSeen =>
      _box?.get(_introSeenKey, defaultValue: false) == true;

  Future<void> markIntroSeen() async {
    await _box?.put(_introSeenKey, true);
  }
}
