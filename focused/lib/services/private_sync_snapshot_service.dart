import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../services/app_category_storage_service.dart';
import '../services/focus_analysis_storage_service.dart';
import '../services/focus_session_storage_service.dart';
import '../services/habit_storage_service.dart';
import '../services/task_occurrence_completion_storage_service.dart';
import '../services/task_storage_service.dart';
import '../services/user_profile_storage_service.dart';
import 'private_sync_crypto_service.dart';

class PrivateSyncSnapshotExport {
  const PrivateSyncSnapshotExport({
    required this.compressedBytes,
    required this.clearTextHash,
    required this.summary,
  });

  final List<int> compressedBytes;
  final String clearTextHash;
  final Map<String, int> summary;
}

class PrivateSyncSnapshotService {
  PrivateSyncSnapshotService({
    required TaskStorageService taskStorageService,
    required TaskOccurrenceCompletionStorageService
        occurrenceCompletionStorage,
    required FocusSessionStorageService
        focusSessionStorageService,
    required HabitStorageService habitStorageService,
    required UserProfileStorageService
        userProfileStorageService,
    required AppCategoryStorageService
        appCategoryStorageService,
    required FocusAnalysisStorageService
        focusAnalysisStorageService,
    PrivateSyncCryptoService? cryptoService,
  })  : _taskStorageService = taskStorageService,
        _occurrenceCompletionStorage =
            occurrenceCompletionStorage,
        _focusSessionStorageService =
            focusSessionStorageService,
        _habitStorageService = habitStorageService,
        _userProfileStorageService =
            userProfileStorageService,
        _appCategoryStorageService =
            appCategoryStorageService,
        _focusAnalysisStorageService =
            focusAnalysisStorageService,
        _cryptoService =
            cryptoService ??
            PrivateSyncCryptoService();

  final TaskStorageService _taskStorageService;
  final TaskOccurrenceCompletionStorageService
      _occurrenceCompletionStorage;
  final FocusSessionStorageService
      _focusSessionStorageService;
  final HabitStorageService _habitStorageService;
  final UserProfileStorageService
      _userProfileStorageService;
  final AppCategoryStorageService
      _appCategoryStorageService;
  final FocusAnalysisStorageService
      _focusAnalysisStorageService;
  final PrivateSyncCryptoService _cryptoService;

  Future<PrivateSyncSnapshotExport> export() async {
    final tasks = _taskStorageService
        .loadTasks()
        .map((item) => item.toMap())
        .toList(growable: false);

    final completions = _occurrenceCompletionStorage
        .loadCompletions()
        .map((item) => item.toMap())
        .toList(growable: false);

    final focusSessions = _focusSessionStorageService
        .loadSessions()
        .map((item) => item.toMap())
        .toList(growable: false);

    final habits = _habitStorageService
        .loadHabits()
        .map((item) => item.toMap())
        .toList(growable: false);

    final habitProgress = _habitStorageService
        .loadProgress()
        .map((item) => item.toMap())
        .toList(growable: false);

    final userProfile =
        _userProfileStorageService
            .loadProfile()
            ?.toMap();

    final appCategories =
        await _appCategoryStorageService.loadAll();

    final focusAnalyses =
        _focusAnalysisStorageService
            .loadAll()
            .map(
              (item) => {
                'sessionId': item.sessionId,
                'savedAt':
                    item.savedAt.toIso8601String(),
                'analysis': item.analysis.toMap(),
              },
            )
            .toList(growable: false);

    final snapshot = <String, dynamic>{
      'schemaVersion': 1,
      'scope':
          'focused-owned-state-without-raw-device-usage',
      'tasks': tasks,
      'taskOccurrenceCompletions': completions,
      'focusSessions': focusSessions,
      'habits': habits,
      'habitProgress': habitProgress,
      'userProfile': userProfile,
      'appCategories': appCategories.map(
        (appId, category) =>
            MapEntry(appId, category.name),
      ),
      'focusAnalyses': focusAnalyses,

      // Raw Android UsageStats records are deliberately excluded.
      // They are device telemetry, not account-owned cloud state.
      'rawUsageStatsIncluded': false,
    };

    final canonical =
        _canonicalize(snapshot);
    final clearText =
        utf8.encode(jsonEncode(canonical));

    return PrivateSyncSnapshotExport(
      compressedBytes:
          List<int>.unmodifiable(
        gzip.encode(clearText),
      ),
      clearTextHash:
          await _cryptoService.sha256Hex(clearText),
      summary: {
        'tasks': tasks.length,
        'taskOccurrenceCompletions':
            completions.length,
        'focusSessions': focusSessions.length,
        'habits': habits.length,
        'habitProgress': habitProgress.length,
        'appCategories': appCategories.length,
        'focusAnalyses': focusAnalyses.length,
      },
    );
  }

  Map<String, dynamic> decodeCompressedSnapshot(
    List<int> compressedBytes,
  ) {
    final clearText = gzip.decode(compressedBytes);
    final decoded =
        jsonDecode(utf8.decode(clearText));

    if (decoded is! Map) {
      throw const FormatException(
        'Private sync snapshot is not a JSON object.',
      );
    }

    final map =
        Map<String, dynamic>.from(decoded);

    if (map['schemaVersion'] != 1) {
      throw const FormatException(
        'Unsupported private sync snapshot version.',
      );
    }

    return map;
  }

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final sorted =
          SplayTreeMap<String, dynamic>();

      for (final entry in value.entries) {
        sorted[entry.key.toString()] =
            _canonicalize(entry.value);
      }

      return sorted;
    }

    if (value is List) {
      return value
          .map(_canonicalize)
          .toList(growable: false);
    }

    return value;
  }
}
