import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable frosted glass container with blur, gradient tint, and glowing specular border.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? color;
  final Border? border;
  final BoxShadow? shadow;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 16.0,
    this.color,
    this.border,
    this.shadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(24);

    final defaultBgColor =
        color ??
        (isDark
            ? const Color(0xFF141622).withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.82));

    final defaultBorder =
        border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.1,
        );

    final defaultShadow =
        shadow ??
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF4F46E5).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        );

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: defaultBgColor,
            borderRadius: radius,
            border: defaultBorder,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(borderRadius: radius, onTap: onTap, child: content),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [defaultShadow],
      ),
      child: content,
    );
  }
}

/// Ambient soft gradient mesh backdrop wrapper for glossy glass pages.
/// Uses smooth RadialGradients for glitch-free 120 FPS rendering on all devices.
class GlassScaffoldBackground extends StatelessWidget {
  final Widget child;

  const GlassScaffoldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Ambient background base
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF090A0F),
                        Color(0xFF0E1017),
                        Color(0xFF0B0C12),
                      ]
                    : const [
                        Color(0xFFF7F9FC),
                        Color(0xFFEEF2F9),
                        Color(0xFFF9FAFD),
                      ],
              ),
            ),
          ),
        ),
        // Ambient color glow orbs (smooth RadialGradients, no compositor glitch)
        Positioned(
          top: -100,
          right: -80,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF6366F1).withValues(alpha: 0.18),
                          const Color(0xFFEC4899).withValues(alpha: 0.08),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0xFF818CF8).withValues(alpha: 0.12),
                          const Color(0xFFF472B6).withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 240,
          left: -90,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          const Color(0xFF3B82F6).withValues(alpha: 0.05),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0xFF38BDF8).withValues(alpha: 0.10),
                          const Color(0xFF60A5FA).withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          right: -60,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                          const Color(0xFFEC4899).withValues(alpha: 0.07),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0xFFA78BFA).withValues(alpha: 0.12),
                          const Color(0xFFF472B6).withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
