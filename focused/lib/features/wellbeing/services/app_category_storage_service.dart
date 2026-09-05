import 'package:hive_ce/hive_ce.dart';

import '../models/app_category.dart';

abstract class AppCategoryStore {
  Future<void> init();

  Future<Map<String, AppCategory>> loadAll();

  Future<void> saveCategory(String appId, AppCategory category);

  Future<void> deleteCategory(String appId);
}

class AppCategoryStorageService implements AppCategoryStore {
  static const String _boxName = 'focused_app_categories_v1';

  Box<dynamic>? _box;

  @override
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requiredBox {
    final box = _box;
    if (box == null) {
      throw StateError(
        'AppCategoryStorageService.init() must be called first.',
      );
    }
    return box;
  }

  @override
  Future<Map<String, AppCategory>> loadAll() async {
    final result = <String, AppCategory>{};

    for (final key in _requiredBox.keys) {
      if (key is! String || key.trim().isEmpty) {
        continue;
      }

      final raw = _requiredBox.get(key);
      if (raw is! String) {
        continue;
      }

      AppCategory? category;
      for (final value in AppCategory.values) {
        if (value.name == raw) {
          category = value;
          break;
        }
      }

      if (category != null) {
        result[key] = category;
      }
    }

    return Map<String, AppCategory>.unmodifiable(result);
  }

  @override
  Future<void> saveCategory(String appId, AppCategory category) async {
    final normalized = appId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(appId, 'appId', 'App id cannot be empty.');
    }

    await _requiredBox.put(normalized, category.name);
  }

  @override
  Future<void> deleteCategory(String appId) async {
    await _requiredBox.delete(appId.trim());
  }
}
