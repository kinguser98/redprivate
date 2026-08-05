import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Color? gradientStart;
  final Color? gradientEnd;
  final double borderRadius;
  final double fontSize;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.width = double.infinity,
    this.height = 56,
    this.onTap,
    this.gradientStart,
    this.gradientEnd,
    this.borderRadius = 28,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final start = gradientStart ?? const Color(0xFF6C63FF);
    final end = gradientEnd ?? const Color(0xFF3F3D9E);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            colors: [start, end],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: start.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            splashColor: Colors.white.withOpacity(0.2),
            highlightColor: Colors.transparent,
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color? accent;
  final String? label;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.size = 48,
    this.onTap,
    this.accent,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: effectiveAccent.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: size * 0.45),
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
