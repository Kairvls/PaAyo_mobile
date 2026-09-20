class SemesterCampaignProgress {
  final int total;
  final int inspected;
  final int pending;
  final int defects;
  final int percent;

  const SemesterCampaignProgress({
    required this.total,
    required this.inspected,
    required this.pending,
    required this.defects,
    required this.percent,
  });

  factory SemesterCampaignProgress.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    int n(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;
    return SemesterCampaignProgress(
      total: n(json["total"]),
      inspected: n(json["inspected"]),
      pending: n(json["pending"]),
      defects: n(json["defects"]),
      percent: n(json["percent"]),
    );
  }
}

class SemesterCampaign {
  final int id;
  final String title;
  final String? academicYear;
  final String semester;
  final String status;
  final DateTime? dueDate;
  final DateTime? startDate;
  final String scopeType;
  final String scopeLabel;
  final String? notes;
  final SemesterCampaignProgress progress;

  const SemesterCampaign({
    required this.id,
    required this.title,
    this.academicYear,
    required this.semester,
    required this.status,
    this.dueDate,
    this.startDate,
    required this.scopeType,
    required this.scopeLabel,
    this.notes,
    required this.progress,
  });

  bool get isOpen => status == "Active" || status == "In Progress";

  factory SemesterCampaign.fromJson(Map<String, dynamic> json) {
    DateTime? d(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return SemesterCampaign(
      id: int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      title: json["title"]?.toString() ?? "Campaign",
      academicYear: json["academic_year"]?.toString(),
      semester: json["semester"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "",
      dueDate: d(json["due_date"]),
      startDate: d(json["start_date"]),
      scopeType: json["scope_type"]?.toString() ?? "campus",
      scopeLabel: json["scope_label"]?.toString() ?? "Campus",
      notes: json["notes"]?.toString(),
      progress: SemesterCampaignProgress.fromJson(
        json["progress"] is Map
            ? Map<String, dynamic>.from(json["progress"] as Map)
            : null,
      ),
    );
  }
}

class SemesterInspectionItem {
  final int id;
  final int campaignId;
  final int equipmentId;
  final String status;
  final String? condition;
  final String? findings;
  final String? actionTaken;
  final DateTime? inspectedAt;
  final String equipmentName;
  final String? assetTag;
  final String? qrCode;
  final String room;
  final String category;
  final String? inventoryStatus;
  final String? conditionStatus;

  const SemesterInspectionItem({
    required this.id,
    required this.campaignId,
    required this.equipmentId,
    required this.status,
    this.condition,
    this.findings,
    this.actionTaken,
    this.inspectedAt,
    required this.equipmentName,
    this.assetTag,
    this.qrCode,
    required this.room,
    required this.category,
    this.inventoryStatus,
    this.conditionStatus,
  });

  bool get isPending => status == "Pending";
  bool get isInspected => status == "Inspected";

  factory SemesterInspectionItem.fromJson(Map<String, dynamic> json) {
    return SemesterInspectionItem(
      id: int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      campaignId: int.tryParse(json["campaign_id"]?.toString() ?? "") ?? 0,
      equipmentId: int.tryParse(json["equipment_id"]?.toString() ?? "") ?? 0,
      status: json["status"]?.toString() ?? "Pending",
      condition: json["condition"]?.toString(),
      findings: json["findings"]?.toString(),
      actionTaken: json["action_taken"]?.toString(),
      inspectedAt: json["inspected_at"] != null
          ? DateTime.tryParse(json["inspected_at"].toString())
          : null,
      equipmentName: json["equipment_name"]?.toString() ?? "Equipment",
      assetTag: json["asset_tag"]?.toString(),
      qrCode: json["qr_code"]?.toString(),
      room: json["room"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "",
      inventoryStatus: json["inventory_status"]?.toString(),
      conditionStatus: json["condition_status"]?.toString(),
    );
  }
}

class SemesterCampaignDetail {
  final SemesterCampaign campaign;
  final List<SemesterInspectionItem> items;
  final List<String> rooms;
  final List<String> conditions;

  const SemesterCampaignDetail({
    required this.campaign,
    required this.items,
    required this.rooms,
    required this.conditions,
  });
}
