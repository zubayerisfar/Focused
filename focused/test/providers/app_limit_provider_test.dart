import 'package:flutter_test/flutter_test.dart';
import 'package:focused/features/wellbeing/models/app_limit.dart';
import 'package:focused/features/wellbeing/providers/app_limit_provider.dart';
import 'package:focused/features/wellbeing/services/app_limit_storage_service.dart';

class InMemoryAppLimitStore implements AppLimitStore {
  final Map<String, AppLimit> _storage = {};

  @override
  Future<void> init() async {}

  @override
  List<AppLimit> loadLimits() => List.unmodifiable(_storage.values);

  @override
  Future<void> saveLimit(AppLimit limit) async {
    _storage[limit.packageId] = limit;
  }

  @override
  Future<void> deleteLimit(String packageId) async {
    _storage.remove(packageId);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }
}

void main() {
  late InMemoryAppLimitStore store;
  late AppLimitProvider provider;

  setUp(() async {
    store = InMemoryAppLimitStore();
    provider = AppLimitProvider(storageService: store);
    await provider.loadStoredLimits();
  });

  test('sets and toggles app limit', () async {
    await provider.setLimit(
      packageId: 'com.google.android.youtube',
      appName: 'YouTube',
      dailyLimitMinutes: 120,
    );

    expect(provider.limits.length, 1);
    final limit = provider.getLimit('com.google.android.youtube');
    expect(limit, isNotNull);
    expect(limit!.appName, 'YouTube');
    expect(limit.dailyLimitMinutes, 120);
    expect(limit.isEnabled, isTrue);

    await provider.toggleLimit('com.google.android.youtube');
    expect(provider.getLimit('com.google.android.youtube')!.isEnabled, isFalse);

    await provider.toggleLimit('com.google.android.youtube');
    expect(provider.getLimit('com.google.android.youtube')!.isEnabled, isTrue);
  });

  test('checks usage limits and tracks warning timestamp', () async {
    await provider.setLimit(
      packageId: 'com.google.android.youtube',
      appName: 'YouTube',
      dailyLimitMinutes: 60,
    );

    // Below limit
    await provider.checkUsageLimits({
      'com.google.android.youtube': const Duration(minutes: 45),
    });
    expect(
      provider.getLimit('com.google.android.youtube')!.lastWarningDate,
      isNull,
    );

    // Reaches/exceeds limit
    await provider.checkUsageLimits({
      'com.google.android.youtube': const Duration(minutes: 65),
    });
    expect(
      provider.getLimit('com.google.android.youtube')!.lastWarningDate,
      isNotNull,
    );
  });

  test('removes app limit', () async {
    await provider.setLimit(
      packageId: 'com.instagram.android',
      appName: 'Instagram',
      dailyLimitMinutes: 30,
    );

    expect(provider.limits.length, 1);
    await provider.removeLimit('com.instagram.android');
    expect(provider.limits, isEmpty);
  });
}
