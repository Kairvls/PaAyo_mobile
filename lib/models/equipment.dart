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
/// `user_full_name`) returned by `GET /api/maintenance/history/{id}`.
class MaintenanceRecord {
  final DateTime date;
  final String status;
  final String personnel;
  final String? findings;
  final String? repairAction;
  final String? replacementRemarks;

  const MaintenanceRecord({
    required this.date,
    required this.status,
    required this.personnel,
    this.findings,
    this.repairAction,
    this.replacementRemarks,
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
    );
  }
}

/// A maintenance schedule row for a piece of equipment.
///
/// Maps rows from `maintenance_schedules_table` returned by
/// `GET /api/maintenance/schedule/{equipmentId}`.
class MaintenanceSchedule {
  final int id;
  final String title;
  final String? description;
  final String frequency;
  final DateTime? nextDate;
  final DateTime? lastDate;
  final String status;

  const MaintenanceSchedule({
    required this.id,
    required this.title,
    required this.frequency,
    required this.status,
    this.description,
    this.nextDate,
    this.lastDate,
  });

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
    );
  }
}
