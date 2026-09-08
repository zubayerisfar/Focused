import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'F';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words.first[0] + words.last[0]).toUpperCase();
}

class HomeHeader extends StatelessWidget {
  final int streak;
  final String? photoUrl;
  final String displayName;
  final int xpPoints;
  final bool isInDanger;

  const HomeHeader({super.key, 
    required this.streak,
    required this.photoUrl,
    required this.displayName,
    required this.xpPoints,
    this.isInDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final streakColor = isInDanger ? const Color(0xFFEF4444) : const Color(0xFFFF9600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Focus',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            // Gem chip
            InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => context.push('/xp'),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF1CB0F6,
                  ).withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: const Color(0xFF1CB0F6).withValues(alpha: 0.32),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icon/gem.svg',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$xpPoints',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1CB0F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Streak chip
            InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => context.push('/streak'),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: streakColor.withValues(alpha: isDark ? 0.18 : 0.13),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: streakColor.withValues(alpha: isInDanger ? 0.6 : 0.32),
                    width: isInDanger ? 1.5 : 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isInDanger ? '⚠️' : '🔥',
                      style: const TextStyle(fontSize: 16, height: 1.0),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$streak',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: streakColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: photoUrl == null
                    ? null
                    : NetworkImage(photoUrl!),
                child: photoUrl == null
                    ? Text(
                        _initials(displayName),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

