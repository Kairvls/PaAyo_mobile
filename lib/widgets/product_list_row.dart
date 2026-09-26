import 'package:flutter/material.dart';

/// Flat list row matching the Product List reference:
/// [thumbnail] | title + gray subtitle | blue action text
/// with a thin divider underneath.
class ProductListRow extends StatelessWidget {
  static const ink = Color(0xFF1A1C1E);
  static const muted = Color(0xFF74777F);
  static const actionBlue = Color(0xFF3B82F6);
  static const thumbBg = Color(0xFFF3F4F6);
  static const divider = Color(0xFFE8EAED);

  final Widget leading;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const ProductListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.actionLabel = "View",
    required this.onTap,
    this.onAction,
    this.showDivider = true,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 16, 14),
  });

  /// Builds a light-gray rounded square thumbnail for icons or graphics.
  static Widget thumbnail({
    required Widget child,
    Color background = thumbBg,
    double size = 56,
    double radius = 12,
    EdgeInsetsGeometry padding = const EdgeInsets.all(10),
  }) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }

  /// Joins subtitle parts with a middle-dot, skipping empties.
  static String joinMeta(List<String?> parts) {
    return parts
        .map((p) => p?.trim() ?? "")
        .where((p) => p.isNotEmpty && p != "—")
        .join(" • ");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: muted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onAction ?? onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: actionBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 90),
            child: Divider(height: 1, thickness: 1, color: divider),
          ),
      ],
    );
  }
}
