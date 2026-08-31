import 'package:flutter/foundation.dart';

import '../services/onboarding_storage_service.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({
    required OnboardingStorageService storageService,
  }) : _storageService = storageService;

  final OnboardingStorageService _storageService;

  bool _introSeen = false;

  bool get introSeen => _introSeen;

  Future<void> load() async {
    _introSeen = _storageService.introSeen;
  }

  Future<void> completeIntro() async {
    if (_introSeen) return;

    _introSeen = true;
    notifyListeners();
    await _storageService.markIntroSeen();
  }
}
