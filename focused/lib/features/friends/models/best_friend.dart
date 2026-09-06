import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Best Friend with a shared productivity streak.
/// Lifecycle:
/// - Each streak cycle lasts 24 hours from `streakStartedAt` (or latest cycle).
/// - If not interacted within 24h, enters a 6-hour "At Risk" window (reddish alert).
/// - If 30h total passes without interaction or ad restore, streak breaks and friend is removed.
class BestFriend {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int streakDays;
  final DateTime streakStartedAt;
  final DateTime currentCycleStartedAt;
  final DateTime? lastInteractedAt;
  final bool isRestoredViaAd;

  const BestFriend({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.streakDays = 1,
    required this.streakStartedAt,
    required this.currentCycleStartedAt,
    this.lastInteractedAt,
    this.isRestoredViaAd = false,
  });

  String get handle {
    final clean = username.trim();
    if (clean.isNotEmpty && clean != 'user') {
      return clean.startsWith('@') ? clean : '@$clean';
    }
    final nameClean = displayName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (nameClean.isNotEmpty && nameClean != 'focuseduser') {
      return '@$nameClean';
    }
    return '@user';
  }

  /// Has the user interacted today (in the current 24-hour window)?
  bool get hasInteractedInCurrentCycle {
    if (lastInteractedAt == null) return false;
    return lastInteractedAt!.isAfter(currentCycleStartedAt);
  }

  /// Total elapsed time since current cycle started
  Duration get elapsedInCycle {
    final now = DateTime.now().toUtc();
    return now.difference(currentCycleStartedAt.toUtc());
  }

  /// True if 24 hours have elapsed without interaction, but under 30 hours (6-hour grace period)
  bool get isAtRisk {
    if (hasInteractedInCurrentCycle) return false;
    final elapsedHours = elapsedInCycle.inMinutes / 60.0;
    return elapsedHours >= 24.0 && elapsedHours < 30.0;
  }

  /// True if 30+ hours have passed without interaction or recovery
  bool get isExpired {
    if (hasInteractedInCurrentCycle) return false;
    final elapsedHours = elapsedInCycle.inMinutes / 60.0;
    return elapsedHours >= 30.0;
  }

  /// Time remaining in current 24-hour cycle
  Duration get cycleTimeRemaining {
    const cycleDuration = Duration(hours: 24);
    final remaining = cycleDuration - elapsedInCycle;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Time remaining in the 6-hour "At Risk" grace period
  Duration get riskTimeRemaining {
    const totalWithRisk = Duration(hours: 30);
    final remaining = totalWithRisk - elapsedInCycle;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'streakDays': streakDays,
      'streakStartedAt': Timestamp.fromDate(streakStartedAt.toUtc()),
      'currentCycleStartedAt': Timestamp.fromDate(
        currentCycleStartedAt.toUtc(),
      ),
      'lastInteractedAt': lastInteractedAt != null
          ? Timestamp.fromDate(lastInteractedAt!.toUtc())
          : null,
      'isRestoredViaAd': isRestoredViaAd,
    };
  }

  factory BestFriend.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate().toUtc();
      if (value is String) return DateTime.tryParse(value)?.toUtc() ?? fallback;
      return fallback;
    }

    final now = DateTime.now().toUtc();
    final startedAt = parseDate(map['streakStartedAt'], now);
    final cycleStartedAt = parseDate(map['currentCycleStartedAt'], startedAt);
    DateTime? lastInteracted;
    if (map['lastInteractedAt'] != null) {
      lastInteracted = parseDate(map['lastInteractedAt'], now);
    }

    return BestFriend(
      uid: docId ?? (map['uid']?.toString() ?? ''),
      displayName: map['displayName']?.toString() ?? 'Friend',
      username: map['username']?.toString() ?? 'friend',
      photoUrl: map['photoUrl']?.toString(),
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 1,
      streakStartedAt: startedAt,
      currentCycleStartedAt: cycleStartedAt,
      lastInteractedAt: lastInteracted,
      isRestoredViaAd: map['isRestoredViaAd'] as bool? ?? false,
    );
  }

  BestFriend copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? photoUrl,
    int? streakDays,
    DateTime? streakStartedAt,
    DateTime? currentCycleStartedAt,
    DateTime? lastInteractedAt,
    bool? isRestoredViaAd,
  }) {
    return BestFriend(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      streakDays: streakDays ?? this.streakDays,
      streakStartedAt: streakStartedAt ?? this.streakStartedAt,
      currentCycleStartedAt:
          currentCycleStartedAt ?? this.currentCycleStartedAt,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
      isRestoredViaAd: isRestoredViaAd ?? this.isRestoredViaAd,
    );
  }
}
