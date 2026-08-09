/// Equipment resolved from a scanned QR code.
///
/// Maps the `equipment` object returned by
/// `GET /api/maintenance/equipment/{qr}` on the Laravel backend.
class Equipment {
  final int id;
  final String qrId;
  final String name;
  final String assetTag;
  final String brand;
  final String model;
  final String serial;
  final String room;
  final String category;
  final String condition;
  final String status; // inventory_status
  final String warranty;

  const Equipment({
    required this.id,
    required this.qrId,
    required this.name,
    required this.assetTag,
    required this.brand,
    required this.model,
    required this.serial,
    required this.room,
    required this.category,
    required this.condition,
    required this.status,
    required this.warranty,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    String s(dynamic v, [String fallback = "—"]) {
      final value = v?.toString().trim();
      return (value == null || value.isEmpty || value == "null")
          ? fallback
          : value;
    }

    return Equipment(
      id: int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      qrId: s(json["qr_code"] ?? json["qr_id"]),
      name: s(json["name"] ?? json["equipment_name"], "Equipment"),
      assetTag: s(json["asset_tag"]),
      brand: s(json["brand"] ?? json["brand_name"]),
      model: s(json["model"]),
      serial: s(json["serial_number"] ?? json["serial"]),
      room: s(json["room"] ?? json["room_name"]),
      category: s(json["category"]),
      condition: s(json["condition"] ?? json["condition_status"]),
      status: s(json["inventory_status"] ?? json["status"], "Unknown"),
      warranty: s(json["warranty_expiration"] ?? json["warranty"]),
    );
  }
}

/// A single maintenance record for the history timeline.
///
/// Maps rows from `equipment_maintenance_history_table` (+ joined
/// `user_full_name`) returned by `GET /api/maintenance/history/{id}`
/// and the global `GET /api/maintenance/histories` list.
class MaintenanceRecord {
  final DateTime date;
  final String status;
  final String personnel;
  final String? findings;
  final String? repairAction;
  final String? replacementRemarks;
  final int? equipmentId;
  final String? equipmentName;
  final String? equipmentQr;
  final String? room;

  const MaintenanceRecord({
    required this.date,
    required this.status,
    required this.personnel,
    this.findings,
    this.repairAction,
    this.replacementRemarks,
    this.equipmentId,
    this.equipmentName,
    this.equipmentQr,
    this.room,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    String? sn(dynamic v) {
      final value = v?.toString().trim();
      return (value == null || value.isEmpty || value == "null") ? null : value;
    }

    return MaintenanceRecord(
      date: DateTime.tryParse(
            (json["equipment_maintenance_created_at"] ??
                    json["equipment_maintenance_completed_at"] ??
                    "")
                .toString(),
          ) ??
          DateTime.now(),
      status: sn(json["equipment_maintenance_status"]) ?? "Maintenance",
      personnel: sn(json["user_full_name"]) ?? "Maintenance Personnel",
      findings: sn(json["equipment_maintenance_findings"]),
      repairAction: sn(json["equipment_maintenance_repair_action"]),
      replacementRemarks: sn(json["equipment_maintenance_replacement_remarks"]),
      equipmentId: int.tryParse(
        (json["equipment_id"] ?? json["equipment_maintenance_equipment_id"])
                ?.toString() ??
            "",
      ),
      equipmentName: sn(json["equipment_name"]),
      equipmentQr: sn(json["equipment_qr_code"] ?? json["qr_code"]),
      room: sn(json["room_name"] ?? json["room"]),
    );
  }
}

/// A maintenance schedule row for a piece of equipment.
///
/// Maps rows from `maintenance_schedules_table` returned by
/// `GET /api/maintenance/schedule/{equipmentId}` and the global
/// `GET /api/maintenance/schedules` list.
class MaintenanceSchedule {
  /// How many days before [nextDate] a schedule is treated as "Due soon".
  static const int dueSoonDays = 7;

  final int id;
  final String title;
  final String? description;
  final String frequency;
  final DateTime? nextDate;
  final DateTime? lastDate;
  final String status;
  final int? equipmentId;
  final String? equipmentName;
  final String? equipmentQr;
  final String? room;

  const MaintenanceSchedule({
    required this.id,
    required this.title,
    required this.frequency,
    required this.status,
    this.description,
    this.nextDate,
    this.lastDate,
    this.equipmentId,
    this.equipmentName,
    this.equipmentQr,
    this.room,
  });

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get isOverdue {
    if (status.toLowerCase().contains("overdue")) return true;
    if (nextDate == null) return false;
    final d = DateTime(nextDate!.year, nextDate!.month, nextDate!.day);
    return d.isBefore(_today);
  }

  /// True when next date is today through [dueSoonDays] days ahead.
  bool get isDueSoon {
    if (nextDate == null || isOverdue) return false;
    final d = DateTime(nextDate!.year, nextDate!.month, nextDate!.day);
    final end = _today.add(const Duration(days: dueSoonDays));
    return !d.isBefore(_today) && !d.isAfter(end);
  }

  /// Display label: Overdue → Due soon → stored status.
  String get urgencyLabel {
    if (isOverdue) return "Overdue";
    if (isDueSoon) return "Due soon";
    return status;
  }

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) {
    String? sn(dynamic v) {
      final value = v?.toString().trim();
      return (value == null || value.isEmpty || value == "null") ? null : value;
    }

    DateTime? d(dynamic v) => DateTime.tryParse(v?.toString() ?? "");

    return MaintenanceSchedule(
      id: int.tryParse(json["maintenance_schedule_id"]?.toString() ?? "") ?? 0,
      title: sn(json["maintenance_schedule_title"]) ?? "Maintenance",
      description: sn(json["maintenance_schedule_description"]),
      frequency: sn(json["maintenance_schedule_frequency"]) ?? "—",
      nextDate: d(json["maintenance_schedule_next_date"]),
      lastDate: d(json["maintenance_schedule_last_date"]),
      status: sn(json["maintenance_schedule_status"]) ?? "Active",
      equipmentId: int.tryParse(
        (json["equipment_id"] ?? json["maintenance_schedule_equipment_id"])
                ?.toString() ??
            "",
      ),
      equipmentName: sn(json["equipment_name"]),
      equipmentQr: sn(json["equipment_qr_code"] ?? json["qr_code"]),
      room: sn(json["room_name"] ?? json["room"]),
    );
  }
}

/// Aggregated recent activity for the maintenance home dashboard.
class MaintenanceRecent {
  final int equipmentCount;
  final int underMaintenance;
  final int overdueSchedules;
  final int dueSoonSchedulesCount;
  final int dueSoonDays;
  final List<MaintenanceRecord> recentHistory;
  final List<MaintenanceSchedule> dueSoonSchedules;
  final List<MaintenanceSchedule> upcomingSchedules;
  final List<Equipment> attentionEquipment;

  const MaintenanceRecent({
    required this.equipmentCount,
    required this.underMaintenance,
    required this.overdueSchedules,
    required this.dueSoonSchedulesCount,
    required this.dueSoonDays,
    required this.recentHistory,
    required this.dueSoonSchedules,
    required this.upcomingSchedules,
    required this.attentionEquipment,
  });

  factory MaintenanceRecent.fromJson(Map<String, dynamic> json) {
    final summary = json["summary"] is Map
        ? Map<String, dynamic>.from(json["summary"] as Map)
        : <String, dynamic>{};

    List<T> mapList<T>(dynamic raw, T Function(Map<String, dynamic>) map) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList();
    }

    return MaintenanceRecent(
      equipmentCount:
          int.tryParse(summary["equipment_count"]?.toString() ?? "") ?? 0,
      underMaintenance:
          int.tryParse(summary["under_maintenance"]?.toString() ?? "") ?? 0,
      overdueSchedules:
          int.tryParse(summary["overdue_schedules"]?.toString() ?? "") ?? 0,
      dueSoonSchedulesCount:
          int.tryParse(summary["due_soon_schedules"]?.toString() ?? "") ?? 0,
      dueSoonDays: int.tryParse(summary["due_soon_days"]?.toString() ?? "") ??
          MaintenanceSchedule.dueSoonDays,
      recentHistory:
          mapList(json["recent_history"], MaintenanceRecord.fromJson),
      dueSoonSchedules:
          mapList(json["due_soon_schedules"], MaintenanceSchedule.fromJson),
      upcomingSchedules:
          mapList(json["upcoming_schedules"], MaintenanceSchedule.fromJson),
      attentionEquipment:
          mapList(json["attention_equipment"], Equipment.fromJson),
    );
  }
}
