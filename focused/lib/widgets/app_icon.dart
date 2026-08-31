import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  final Uint8List? iconBytes;
  final String appName;
  final double size;
  final double borderRadius;
  final Color? fallbackBackground;
  final Color? fallbackForeground;

  const AppIcon({
    super.key,
    required this.iconBytes,
    required this.appName,
    this.size = 40,
    this.borderRadius = 12,
    this.fallbackBackground,
    this.fallbackForeground,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = iconBytes;

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fallbackBackground ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        _fallbackLetter(appName),
        style: TextStyle(
          color: fallbackForeground ?? scheme.onSurfaceVariant,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (bytes == null || bytes.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  String _fallbackLetter(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    final parts = trimmed
        .split('.')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    final source = parts.isEmpty ? trimmed : parts.last;
    return source.substring(0, 1).toUpperCase();
  }
}
