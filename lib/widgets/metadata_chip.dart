import 'package:flutter/material.dart';

class MetadataChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? accent;

  const MetadataChip({
    super.key,
    required this.label,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? const Color(0xFF6C63FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveAccent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class MetadataRow extends StatelessWidget {
  final List<String> items;

  const MetadataRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) => MetadataChip(label: item)).toList(),
    );
  }
}
