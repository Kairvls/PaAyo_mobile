import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrismButton extends StatelessWidget {
  final String text;

  final VoidCallback onPressed;

  const PrismButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,

      child: FilledButton(
        onPressed: onPressed,

        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,

          foregroundColor: Colors.white,

          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}