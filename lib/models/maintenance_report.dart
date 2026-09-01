class MaintenanceReportItem {
  final int id;
  final int? equipmentId;
  final String equipmentName;
  final String? unlistedName;
  final String? issue;
  final String? description;
  final String status;
  final String? assetTag;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? category;
  final String? condition;
  final String? inventoryStatus;
  final String? quantity;
  final String? trackingMode;
  final String? qtyMode;
  final String? warrantyExpiration;
  final String? acquiredDate;
  final String? purchaseDate;
  final String? purchaseCost;
  final String? room;
  final String? zone;
  final bool? borrowable;
  final String? placement;
  final String? image;
  final bool isListed;

  const MaintenanceReportItem({
    required this.id,
    this.equipmentId,
    required this.equipmentName,
    this.unlistedName,
    this.issue,
    this.description,
    required this.status,
    this.assetTag,
    this.brand,
    this.model,
    this.serialNumber,
    this.category,
    this.condition,
    this.inventoryStatus,
    this.quantity,
    this.trackingMode,
    this.qtyMode,
    this.warrantyExpiration,
    this.acquiredDate,
    this.purchaseDate,
    this.purchaseCost,
    this.room,
    this.zone,
    this.borrowable,
    this.placement,
    this.image,
    this.isListed = true,
  });

  factory MaintenanceReportItem.fromJson(Map<String, dynamic> json) {
    String? sn(dynamic v) {
      final value = v?.toString().trim();
      return (value == null || value.isEmpty || value == "null") ? null : value;
    }

    bool? bn(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      final text = v.toString().toLowerCase();
      if (text == "true" || text == "1") return true;
      if (text == "false" || text == "0") return false;
      return null;
    }

    return MaintenanceReportItem(
      id: int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      equipmentId: int.tryParse(json["equipment_id"]?.toString() ?? ""),
      equipmentName: sn(json["equipment_name"]) ?? "Equipment",
      unlistedName: sn(json["unlisted_name"]),
      issue: sn(json["issue"]),
      description: sn(json["description"]),
      status: sn(json["status"]) ?? "Pending",
      assetTag: sn(json["asset_tag"]),
      brand: sn(json["brand"]),
      model: sn(json["model"]),
      serialNumber: sn(json["serial_number"]),
      category: sn(json["category"]),
      condition: sn(json["condition"]),
      inventoryStatus: sn(json["inventory_status"]),
      quantity: sn(json["quantity"]),
      trackingMode: sn(json["tracking_mode"]),
      qtyMode: sn(json["qty_mode"]),
      warrantyExpiration: sn(json["warranty_expiration"]),
      acquiredDate: sn(json["acquired_date"]),
      purchaseDate: sn(json["purchase_date"]),
      purchaseCost: sn(json["purchase_cost"]),
      room: sn(json["room"]),
      zone: sn(json["zone"]),
      borrowable: bn(json["borrowable"]),
      placement: sn(json["placement"]),
      image: sn(json["image"]),
      isListed: json["is_listed"] != false,
    );
  }

  bool get isOpen => status == "Pending" || status == "Processing";

  bool get isTerminal =>
      status == "Resolved" ||
      status == "For Replacement" ||
      status == "Rejected";

  /// Detail rows for the equipment profile grid (matches web full profile).
  List<MapEntry<String, String>> get profileRows {
    String dash(String? v) =>
        (v == null || v.trim().isEmpty) ? "—" : v.trim();

    return [
      MapEntry("Brand", dash(brand)),
      MapEntry("Model", dash(model)),
      MapEntry("Serial number", dash(serialNumber)),
      MapEntry("Asset tag", dash(assetTag)),
      MapEntry("Category", dash(category)),
      MapEntry("Qty / Mode", dash(qtyMode ?? quantity)),
      MapEntry("Condition", dash(condition)),
      MapEntry("Inventory status", dash(inventoryStatus)),
      MapEntry("Warranty expiration", dash(warrantyExpiration)),
      MapEntry("Received", dash(acquiredDate)),
      MapEntry("Room", dash(room)),
      MapEntry("Zone", dash(zone)),
      MapEntry(
        "Borrowable",
        borrowable == null ? "—" : (borrowable! ? "Yes" : "No"),
      ),
      if (purchaseDate != null && purchaseDate!.isNotEmpty)
        MapEntry("Purchased", dash(purchaseDate)),
      if (purchaseCost != null && purchaseCost!.isNotEmpty)
        MapEntry("Purchase cost", dash(purchaseCost)),
      MapEntry("Placement", dash(placement)),
    ];
  }
}

class MaintenanceReport {
  final int id;
  final String ticketCode;
  final String status;
  final String urgency;
  final String room;
  final int? roomId;
  final String equipmentDisplay;
  final String issueDisplay;
  final String? description;
  final String? reporterName;
  final String? reporterEmployeeId;
  final String? assignedPersonnelName;
  final int? assignedPersonnelId;
  final String? assignedPurchaserName;
  final int? assignedPurchaserId;
  final bool isArchived;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final DateTime? preferredActionDate;
  final int itemCount;
  final List<MaintenanceReportItem> items;

  const MaintenanceReport({
    required this.id,
    required this.ticketCode,
    required this.status,
    required this.urgency,
    required this.room,
    this.roomId,
    required this.equipmentDisplay,
    required this.issueDisplay,
    this.description,
    this.reporterName,
    this.reporterEmployeeId,
    this.assignedPersonnelName,
    this.assignedPersonnelId,
    this.assignedPurchaserName,
    this.assignedPurchaserId,
    this.isArchived = false,
    this.submittedAt,
    this.updatedAt,
    this.preferredActionDate,
    required this.itemCount,
    required this.items,
  });

  factory MaintenanceReport.fromJson(Map<String, dynamic> json) {
    String s(dynamic v, [String fallback = ""]) {
      final value = v?.toString().trim();
      return (value == null || value.isEmpty || value == "null")
          ? fallback
          : value;
    }

    DateTime? dt(dynamic v) {
      final raw = v?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final rawItems = json["items"];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) =>
                MaintenanceReportItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MaintenanceReportItem>[];

    return MaintenanceReport(
      id: int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      ticketCode: s(json["ticket_code"], "RPT"),
      status: s(json["status"], "Pending"),
      urgency: s(json["urgency"], "Non-Urgent"),
      room: s(json["room"]),
      roomId: int.tryParse(json["room_id"]?.toString() ?? ""),
      equipmentDisplay: s(json["equipment_display"], "Not specified"),
      issueDisplay: s(json["issue_display"], "No issue"),
      description: json["description"]?.toString(),
      reporterName: json["reporter_name"]?.toString(),
      reporterEmployeeId: json["reporter_employee_id"]?.toString(),
      assignedPersonnelName: json["assigned_personnel_name"]?.toString(),
      assignedPersonnelId:
          int.tryParse(json["assigned_personnel_id"]?.toString() ?? ""),
      assignedPurchaserName: json["assigned_purchaser_name"]?.toString(),
      assignedPurchaserId:
          int.tryParse(json["assigned_purchaser_id"]?.toString() ?? ""),
      isArchived: json["is_archived"] == true || json["is_archived"] == 1,
      submittedAt: dt(json["submitted_at"]),
      updatedAt: dt(json["updated_at"]),
      preferredActionDate: dt(json["preferred_action_date"]),
      itemCount: int.tryParse(json["item_count"]?.toString() ?? "") ??
          items.length,
      items: items,
    );
  }

  bool get isMultiItem => items.length > 1;

  List<MaintenanceReportItem> get openItems =>
      items.where((item) => item.isOpen).toList();

  bool get hasMixedItemStatuses {
    if (items.length <= 1) return false;
    final statuses = items.map((e) => e.status).toSet();
    return statuses.length > 1;
  }

  String get assignedHandler {
    final personnel = assignedPersonnelName?.trim();
    if (personnel != null && personnel.isNotEmpty) return personnel;

    final purchaser = assignedPurchaserName?.trim();
    if (purchaser != null && purchaser.isNotEmpty) return purchaser;

    return "Unassigned";
  }
}
