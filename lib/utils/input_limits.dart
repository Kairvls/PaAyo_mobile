/// Max lengths for mobile report-related text inputs.
/// Keep in sync with backend MobileReportController / InputLimits.
class InputLimits {
  /// API: employee_id max:20 on verify / forgot-pin.
  static const employeeId = 20;

  /// 6-digit reporter PIN.
  static const pin = 6;

  /// API: equipment_details.* / problem description max:2000.
  static const problemDetails = 2000;

  /// API: equipment_issues.* max:255.
  static const issue = 255;

  /// API: remarks / InputLimits::NOTES.
  static const remarks = 500;

  /// Search boxes (rooms, equipment, tickets).
  static const search = 100;
}
