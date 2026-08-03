import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'prism_button.dart';

class FeatureCard extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;

  final VoidCallback onPressed;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),

            blurRadius: 20,

            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .08),

              borderRadius: BorderRadius.circular(16),
            ),

            child: Icon(
              icon,

              color: AppTheme.primaryBlue,

              size: 34,
            ),
          ),

          const SizedBox(height: 22),

          Text(
            title,

            style: const TextStyle(
              fontSize: 23,

              fontWeight: FontWeight.bold,

              color: AppTheme.title,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            description,

            style: const TextStyle(
              fontSize: 15,

              color: AppTheme.subtitle,
            ),
          ),

          const SizedBox(height: 24),

          PrismButton(
            text: "Continue",

            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}