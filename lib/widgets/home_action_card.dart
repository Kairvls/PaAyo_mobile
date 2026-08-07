import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HomeActionCard extends StatelessWidget {
  final String image;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color accent;
  final bool highlightYellow;

  const HomeActionCard({
    super.key,
    required this.image,
    required this.title,
    required this.description,
    required this.onTap,
    this.accent = AppTheme.primaryBlue,
    this.highlightYellow = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = highlightYellow
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFEFF6FF);
    final arrowBg = highlightYellow
        ? const Color(0xFFFEF08A)
        : const Color(0xFFDBEAFE);
    final arrowColor =
        highlightYellow ? const Color(0xFF854D0E) : accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -28,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (highlightYellow
                              ? AppTheme.accentYellow
                              : accent)
                          .withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 22,
                  bottom: 22,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: highlightYellow
                            ? const [
                                AppTheme.accentYellow,
                                AppTheme.primaryBlue,
                              ]
                            : const [
                                AppTheme.primaryBlue,
                                Color(0xFF93C5FD),
                              ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(image),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.title,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: arrowBg,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: arrowColor,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: AppTheme.subtitle,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
