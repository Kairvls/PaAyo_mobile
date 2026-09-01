import 'package:flutter/material.dart';

enum _SweetAlertKind { success, warning, error }

Future<void> _showSweetAlert({
  required BuildContext context,
  required _SweetAlertKind kind,
  required String title,
  required String message,
  String buttonLabel = "OK",
  Color? buttonColor,
}) async {
  const ink = Color(0xFF0F172A);
  const muted = Color(0xFF64748B);
  const actionBlue = Color(0xFF0025CC);

  late Color iconBg;
  late Color iconColor;
  late IconData icon;

  switch (kind) {
    case _SweetAlertKind.success:
      iconBg = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF059669);
      icon = Icons.check_rounded;
      break;
    case _SweetAlertKind.warning:
      iconBg = const Color(0xFFFFFBEB);
      iconColor = const Color(0xFFD97706);
      icon = Icons.info_outline_rounded;
      break;
    case _SweetAlertKind.error:
      iconBg = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.error_outline_rounded;
      break;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor ??
                        (kind == _SweetAlertKind.error
                            ? const Color(0xFFDC2626)
                            : actionBlue),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Sweet Alert–style centered dialog used for success feedback.
Future<void> showSweetAlertSuccess({
  required BuildContext context,
  required String title,
  required String message,
  String buttonLabel = "Done",
}) {
  return _showSweetAlert(
    context: context,
    kind: _SweetAlertKind.success,
    title: title,
    message: message,
    buttonLabel: buttonLabel,
  );
}

Future<void> showSweetAlertWarning({
  required BuildContext context,
  required String title,
  required String message,
  String buttonLabel = "OK",
}) {
  return _showSweetAlert(
    context: context,
    kind: _SweetAlertKind.warning,
    title: title,
    message: message,
    buttonLabel: buttonLabel,
  );
}

Future<void> showSweetAlertError({
  required BuildContext context,
  required String title,
  required String message,
  String buttonLabel = "OK",
}) {
  return _showSweetAlert(
    context: context,
    kind: _SweetAlertKind.error,
    title: title,
    message: message,
    buttonLabel: buttonLabel,
  );
}

String sweetAlertTitleForStatus(String status, {bool partial = false}) {
  if (partial) return "Items updated";

  switch (status) {
    case "Processing":
      return "Processing started";
    case "Resolved":
      return "Resolved";
    case "For Replacement":
      return "Submitted for replacement";
    case "Rejected":
      return "Report rejected";
    default:
      return "Status updated";
  }
}
