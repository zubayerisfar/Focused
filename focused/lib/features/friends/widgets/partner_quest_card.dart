import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/partner_quest.dart';

class PartnerQuestCard extends StatelessWidget {
  final PartnerQuest quest;
  final bool isDark;
  final bool canSendReminder;
  final int remindersUsed;
  final VoidCallback onSendReminder;
  final VoidCallback onSendExp;

  const PartnerQuestCard({super.key, 
    required this.quest,
    required this.isDark,
    required this.canSendReminder,
    required this.remindersUsed,
    required this.onSendReminder,
    required this.onSendExp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Section title + Time remaining
          Row(
            children: [
              Text(
                'Quest with a Friend',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: isDark
                          ? const Color(0xFF77878F)
                          : scheme.onSurfaceVariant,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${quest.hoursRemaining}h left',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Avatars Banner: You + Friend
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF23353E)
                  : scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF1CB0F6),
                  child: Text(
                    'You',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('⚡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF58CC02),
                  backgroundImage: quest.partnerPhotoUrl != null
                      ? NetworkImage(quest.partnerPhotoUrl!)
                      : null,
                  child: quest.partnerPhotoUrl == null
                      ? Text(
                          quest.partnerName.isNotEmpty
                              ? quest.partnerName[0].toUpperCase()
                              : 'F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Goal Title & Progress
          Text(
            quest.goalTitle,
            style: TextStyle(
              color: isDark ? Colors.white : scheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: quest.progressRatio,
              minHeight: 12,
              backgroundColor: isDark
                  ? const Color(0xFF2B3D47)
                  : scheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1CB0F6)),
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown (You: 3, Friend: 6)
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFF1CB0F6), size: 10),
              const SizedBox(width: 6),
              Text(
                'You: ${quest.myProgress} done',
                style: TextStyle(
                  color: isDark ? Colors.white : scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, color: Color(0xFF58CC02), size: 10),
              const SizedBox(width: 6),
              Text(
                '${quest.partnerName}: ${quest.partnerProgress} done',
                style: TextStyle(
                  color: isDark ? Colors.white : scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons: Reminder & Gift (50 EXP)
          Row(
            children: [
              // Reminder Button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : scheme.onSurface,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF37464F)
                          : scheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: canSendReminder ? onSendReminder : null,
                  icon: const Icon(
                    Icons.waving_hand_rounded,
                    color: Color(0xFF1CB0F6),
                    size: 18,
                  ),
                  label: Text(
                    canSendReminder ? 'Reminder' : 'Limit 5/5',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Gift 50 EXP Button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : scheme.onSurface,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF37464F)
                          : scheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onSendExp,
                  icon: SvgPicture.asset(
                    'assets/icon/gift_box_icon.svg',
                    width: 18,
                    height: 18,
                  ),
                  label: const Text(
                    'Gift 50 EXP',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── FRIENDS LIST TAB ──
