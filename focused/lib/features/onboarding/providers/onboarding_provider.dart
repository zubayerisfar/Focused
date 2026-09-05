import 'package:flutter/foundation.dart';

import '../services/onboarding_storage_service.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({
    required OnboardingStorageService storageService,
  }) : _storageService = storageService;

  final OnboardingStorageService _storageService;

  bool _introSeen = false;
  bool _adNoticeSeen = false;

  bool get introSeen => _introSeen;
  bool get adNoticeSeen => _adNoticeSeen;

  Future<void> load() async {
    _introSeen = _storageService.introSeen;
    _adNoticeSeen = _storageService.adNoticeSeen;
  }

  Future<void> completeIntro() async {
    if (_introSeen) return;
    _introSeen = true;
    notifyListeners();
    await _storageService.markIntroSeen();
  }

  Future<void> completeAdNotice() async {
    if (_adNoticeSeen) return;
    _adNoticeSeen = true;
    notifyListeners();
    await _storageService.markAdNoticeSeen();
  }
}
