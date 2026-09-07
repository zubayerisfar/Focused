import 'package:flutter_test/flutter_test.dart';
import 'package:focused/features/friends/models/best_friend.dart';

void main() {
  group('BestFriend Cycle and Rollover Tests', () {
    test('fresh BestFriend within first 24h shows interacted and remaining time', () {
      final now = DateTime.now().toUtc();
      final friend = BestFriend(
        uid: 'user123',
        displayName: 'Alice',
        username: 'alice',
        streakDays: 1,
        streakStartedAt: now.subtract(const Duration(hours: 2)),
        currentCycleStartedAt: now.subtract(const Duration(hours: 2)),
        lastInteractedAt: now.subtract(const Duration(hours: 1)),
      );

      expect(friend.hasInteractedInCurrentCycle, isTrue);
      expect(friend.isAtRisk, isFalse);
      expect(friend.isExpired, isFalse);
      expect(friend.cycleTimeRemaining.inHours, closeTo(22, 1));
    });

    test('friend created 25h ago without interaction enters isAtRisk', () {
      final now = DateTime.now().toUtc();
      final friend = BestFriend(
        uid: 'user123',
        displayName: 'Bob',
        username: 'bob',
        streakDays: 1,
        streakStartedAt: now.subtract(const Duration(hours: 25)),
        currentCycleStartedAt: now.subtract(const Duration(hours: 25)),
        lastInteractedAt: null,
      );

      expect(friend.hasInteractedInCurrentCycle, isFalse);
      expect(friend.isAtRisk, isTrue);
      expect(friend.isExpired, isFalse);
      expect(friend.riskTimeRemaining.inHours, closeTo(5, 1));
    });

    test('friend interacted in previous cycle rolls over after 24h into new cycle', () {
      final now = DateTime.now().toUtc();
      final cycleStart = now.subtract(const Duration(hours: 26));
      final lastInteraction = now.subtract(const Duration(hours: 25));

      final friend = BestFriend(
        uid: 'user123',
        displayName: 'Charlie',
        username: 'charlie',
        streakDays: 1,
        streakStartedAt: cycleStart,
        currentCycleStartedAt: cycleStart,
        lastInteractedAt: lastInteraction,
      );

      expect(friend.hasInteractedInCurrentCycle, isFalse);
      expect(friend.isAtRisk, isFalse);
      expect(friend.isExpired, isFalse);
      expect(friend.cycleTimeRemaining.inHours, closeTo(22, 1));
    });
  });
}
