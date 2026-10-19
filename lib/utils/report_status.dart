import 'package:flutter/material.dart';

/// Equipment report ticket statuses (chronological workflow order).
class ReportStatuses {
  static const pending = "Pending";
  static const processing = "Processing";
  static const forReplacement = "For Replacement";
  static const resolved = "Resolved";
  static const rejected = "Rejected";
  static const closedCancelled = "Closed / Cancelled";

  /// Active-queue tab order.
  static const List<String> active = [
    pending,
    processing,
    forReplacement,
    resolved,
    rejected,
    closedCancelled,
  ];

  /// Archive-queue tab order.
  static const List<String> archive = [
    resolved,
    forReplacement,
    rejected,
    closedCancelled,
  ];

  static Color color(String status) {
    switch (status) {
      case pending:
        return const Color(0xFFF59E0B);
      case processing:
        return const Color(0xFF7C3AED);
      case forReplacement:
        return const Color(0xFFEA580C);
      case resolved:
        return const Color(0xFF16A34A);
      case rejected:
        return const Color(0xFFDC2626);
      case closedCancelled:
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// Report priority levels (highest → lowest). Backed by API `severity`.
class ReportPriorities {
  static const critical = "Critical";
  static const high = "High";
  static const medium = "Medium";
  static const low = "Low";

  static const List<String> all = [
    critical,
    high,
    medium,
    low,
  ];

  static int rank(String? priority) {
    switch (priority) {
      case critical:
        return 4;
      case high:
        return 3;
      case medium:
        return 2;
      case low:
        return 1;
      default:
        return 0;
    }
  }

  /// Map legacy urgency when severity is missing.
  static String fromUrgency(String? urgency) {
    return urgency == "Urgent" ? high : medium;
  }

  static Color color(String priority) {
    switch (priority) {
      case critical:
        return const Color(0xFFB91C1C); // dark red
      case high:
        return const Color(0xFFEA580C); // dark orange
      case medium:
        return const Color(0xFFCA8A04); // yellow/amber
      case low:
        return const Color(0xFF2563EB); // blue
      default:
        return const Color(0xFF64748B);
    }
  }

  static Color softBackground(String priority) {
    return color(priority).withValues(alpha: 0.12);
  }
}
