import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable Matte Frosted Glass Card widget.
///
/// Matches the imported Stitch design exactly:
/// - Heavy BackdropFilter blur (sigma 16)
/// - Translucent white background (0.20 opacity)
/// - Thin luminous white border
/// - Subtle noise/grain texture via shader
/// - Multi-layer drop shadows for 3D floating look
/// - Rounded corners 28px
class MatteFrostedGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enableShadow;
  final bool enableNoise;
  final VoidCallback? onTap;

  const MatteFrostedGlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.cardBorderRadius,
    this.padding = const EdgeInsets.all(AppTheme.cardPadding),
    this.backgroundColor,
    this.borderColor,
    this.enableShadow = true,
    this.enableNoise = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: 0.20);
    final border = borderColor ?? Colors.white.withValues(alpha: 0.40);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: enableShadow ? AppTheme.card3DShadow : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTheme.glassBlurSigma,
              sigmaY: AppTheme.glassBlurSigma,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: border, width: 1),
                // Inner glow effect
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: enableNoise
                  ? Stack(
                      children: [
                        // Noise texture overlay (very subtle grain)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _NoisePainter(),
                          ),
                        ),
                        child,
                      ],
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a very subtle noise/grain texture for matte feel.
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Extremely subtle noise using small random dots
    // Kept minimal for performance on mobile
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Simple pattern-based grain (no heavy computation)
    for (double x = 0; x < size.width; x += 4) {
      for (double y = 0; y < size.height; y += 4) {
        final hash = (x * 7 + y * 13).toInt() % 5;
        if (hash == 0) {
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
