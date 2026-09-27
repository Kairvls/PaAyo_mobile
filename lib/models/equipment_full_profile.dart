/// Full asset profile returned by
/// `GET /api/maintenance/equipment/{id}/profile`, matching the web
/// maintenance "asset details" drawer (overview, procurement, lifecycle,
/// timeline).
class EquipmentFullProfile {
  final int id;
  final String name;
  final String? category;
  final String? roomName;
  final String? inventoryStatus;
  final String? conditionStatus;
  final String? trackingMode;
  final int quantity;
  final String? assetTag;
  final String? serialNumber;
  final String? brand;
  final String? model;
  final String? qrCode;
  final DateTime? qrIssuedAt;
  final String? location;
  final String? placementZone;
  final DateTime? purchaseDate;
  final double? purchaseCost;
  final DateTime? acquiredDate;
  final String? stockedByName;
  final String? stockLotCode;
  final DateTime? warrantyExpiration;
  final int? usefulLifeYears;
  final DateTime? createdAt;
  final String? supplierName;
  final String? supplierStoreType;
  final String? receivingReportNumber;
  final DateTime? receivingReportDate;
  final String? receivingCondition;
  final String? receivedBy;
  final String? purchaseOrderNumber;
  final DateTime? purchaseOrderDate;
  final String? atpNumber;
  final String? risNumber;

  final DateTime? deployedAt;
  final DateTime? lastMovedAt;
  final DateTime? lastMaintenanceAt;
  final DateTime? disposedAt;

  final List<EquipmentTimelineEvent> events;

  const EquipmentFullProfile({
    required this.id,
    required this.name,
    required this.quantity,
    required this.events,
    this.category,
    this.roomName,
    this.inventoryStatus,
    this.conditionStatus,
    this.trackingMode,
    this.assetTag,
    this.serialNumber,
    this.brand,
    this.model,
    this.qrCode,
    this.qrIssuedAt,
    this.location,
    this.placementZone,
    this.purchaseDate,
    this.purchaseCost,
    this.acquiredDate,
    this.stockedByName,
    this.stockLotCode,
    this.warrantyExpiration,
    this.usefulLifeYears,
    this.createdAt,
    this.supplierName,
    this.supplierStoreType,
    this.receivingReportNumber,
    this.receivingReportDate,
    this.receivingCondition,
    this.receivedBy,
    this.purchaseOrderNumber,
    this.purchaseOrderDate,
    this.atpNumber,
    this.risNumber,
    this.deployedAt,
    this.lastMovedAt,
    this.lastMaintenanceAt,
    this.disposedAt,
  });

  /// Purchase date shown the same way the web drawer resolves it.
  DateTime? get boughtOn => purchaseDate ?? purchaseOrderDate;

  /// "Stocked / received" date, falling back like the web drawer.
  DateTime? get stockedOn => acquiredDate ?? receivingReportDate ?? purchaseDate;

  String? get atpRis {
    final parts = [atpNumber, risNumber]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(" / ");
  }

  factory EquipmentFullProfile.fromJson(Map<String, dynamic> json) {
    final eq = json["equipment"] is Map
        ? Map<String, dynamic>.from(json["equipment"] as Map)
        : <String, dynamic>{};
    final lifecycle = json["lifecycle"] is Map
        ? Map<String, dynamic>.from(json["lifecycle"] as Map)
        : <String, dynamic>{};

    return EquipmentFullProfile(
      id: int.tryParse(eq["id"]?.toString() ?? "") ?? 0,
      name: _str(eq["name"]) ?? "Equipment",
      category: _str(eq["category"]),
      roomName: _str(eq["room_name"]),
      inventoryStatus: _str(eq["inventory_status"]),
      conditionStatus: _str(eq["condition_status"]),
      trackingMode: _str(eq["tracking_mode"]),
      quantity: int.tryParse(eq["quantity"]?.toString() ?? "") ?? 1,
      assetTag: _str(eq["asset_tag"]),
      serialNumber: _str(eq["serial_number"]),
      brand: _str(eq["brand"]),
      model: _str(eq["model"]),
      qrCode: _str(eq["qr_code"]),
      qrIssuedAt: _date(eq["qr_issued_at"]),
      location: _str(eq["location"]),
      placementZone: _str(eq["placement_zone"]),
      purchaseDate: _date(eq["purchase_date"]),
      purchaseCost: double.tryParse(eq["purchase_cost"]?.toString() ?? ""),
      acquiredDate: _date(eq["acquired_date"]),
      stockedByName: _str(eq["stocked_by_name"]),
      stockLotCode: _str(eq["stock_lot_code"]),
      warrantyExpiration: _date(eq["warranty_expiration"]),
      usefulLifeYears: int.tryParse(eq["useful_life_years"]?.toString() ?? ""),
      createdAt: _date(eq["created_at"]),
      supplierName: _str(eq["supplier_name"]),
      supplierStoreType: _str(eq["supplier_store_type"]),
      receivingReportNumber: _str(eq["receiving_report_number"]),
      receivingReportDate: _date(eq["receiving_report_date"]),
      receivingCondition: _str(eq["receiving_condition"]),
      receivedBy: _str(eq["received_by"]),
      purchaseOrderNumber: _str(eq["purchase_order_number"]),
      purchaseOrderDate: _date(eq["purchase_order_date"]),
      atpNumber: _str(eq["atp_number"]),
      risNumber: _str(eq["ris_number"]),
      deployedAt: _date(lifecycle["deployed_at"]),
      lastMovedAt: _date(lifecycle["last_moved_at"]),
      lastMaintenanceAt: _date(lifecycle["last_maintenance_at"]),
      disposedAt: _date(lifecycle["disposed_at"]),
      events: (json["events"] is List ? json["events"] as List : const [])
          .whereType<Map>()
          .map((e) => EquipmentTimelineEvent.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}

class EquipmentTimelineEvent {
  final String type;
  final String typeLabel;
  final DateTime? occurredAt;
  final String title;
  final String description;

  const EquipmentTimelineEvent({
    required this.type,
    required this.typeLabel,
    required this.title,
    required this.description,
    this.occurredAt,
  });

  factory EquipmentTimelineEvent.fromJson(Map<String, dynamic> json) {
    return EquipmentTimelineEvent(
      type: _str(json["type"]) ?? "event",
      typeLabel: _str(json["type_label"]) ?? "",
      occurredAt: _date(json["occurred_at"]),
      title: _str(json["title"]) ?? "",
      description: _str(json["description"]) ?? "",
    );
  }
}

String? _str(dynamic v) {
  final value = v?.toString().trim();
  return (value == null || value.isEmpty || value == "null") ? null : value;
}

DateTime? _date(dynamic v) {
  final value = _str(v);
  return value == null ? null : DateTime.tryParse(value);
}
