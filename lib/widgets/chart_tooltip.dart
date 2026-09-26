import 'package:flutter/material.dart';

/// Shared floating tooltip bubble used by interactive charts.
class ChartTooltipBubble extends StatelessWidget {
  final String title;
  final List<ChartTooltipRow> rows;

  const ChartTooltipBubble({
    super.key,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 96, maxWidth: 180),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: rows[i].color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        rows[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      rows[i].value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class ChartTooltipRow {
  final Color color;
  final String label;
  final String value;

  const ChartTooltipRow({
    required this.color,
    required this.label,
    required this.value,
  });
}

/// Maps a local X position to the nearest category index.
int chartNearestIndex(double localX, double width, int count) {
  if (count <= 1) return 0;
  final t = (localX / width).clamp(0.0, 1.0);
  return (t * (count - 1)).round().clamp(0, count - 1);
}

String chartFmtValue(double v) {
  if (v >= 1000) {
    final k = v / 1000;
    return k == k.roundToDouble()
        ? "${k.round()}k"
        : "${k.toStringAsFixed(1)}k";
  }
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}
