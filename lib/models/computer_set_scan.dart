import 'equipment.dart';

/// Computer set resolved from a set QR code (maintenance or report scan).
class ComputerSetScan {
  final int id;
  final String tag;
  final String name;
  final String qrCode;
  final int? roomId;
  final String room;
  final List<Equipment> members;
  /// Raw reportable member maps (report flow), keyed parallel to [members]
  /// when those maps carry room_id / location fields.
  final List<Map<String, dynamic>> memberMaps;

  const ComputerSetScan({
    required this.id,
    required this.tag,
    required this.name,
    required this.qrCode,
    required this.members,
    this.roomId,
    this.room = "—",
    this.memberMaps = const [],
  });

  String get displayName {
    final t = tag.trim();
    if (t.isNotEmpty && t != "—") return t;
    final n = name.trim();
    if (n.isNotEmpty && n != "—") return n;
    return "Computer set";
  }

  factory ComputerSetScan.fromJson(
    Map<String, dynamic> setJson,
    List membersRaw,
  ) {
    String s(dynamic v, [String fallback = "—"]) {
      final value = v?.toString().trim();
      return (value == null || value.isEmpty || value == "null")
          ? fallback
          : value;
    }

    final maps = <Map<String, dynamic>>[];
    final members = <Equipment>[];

    for (final raw in membersRaw) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      maps.add(m);

      // Report rows use equipment_* keys; maintenance uses id/name/qr_code.
      final normalized = <String, dynamic>{
        "id": m["id"] ?? m["equipment_id"],
        "qr_code": m["qr_code"] ?? m["equipment_qr_code"],
        "asset_tag": m["asset_tag"] ?? m["equipment_asset_tag"],
        "name": m["name"] ?? m["equipment_name"],
        "brand": m["brand"] ?? m["equipment_brand_name"] ?? m["brand_name"],
        "model": m["model"] ?? m["equipment_model"],
        "serial_number":
            m["serial_number"] ?? m["equipment_serial_number"] ?? m["serial"],
        "room": m["room"] ?? m["room_name"] ?? m["equipment_room_name"],
        "category": m["category"] ?? m["equipment_category_name"],
        "condition": m["condition"] ??
            m["condition_status"] ??
            m["equipment_condition_status"],
        "inventory_status": m["inventory_status"] ??
            m["equipment_inventory_status"] ??
            m["status"],
        "warranty_expiration": m["warranty_expiration"],
      };
      members.add(Equipment.fromJson(normalized));
    }

    return ComputerSetScan(
      id: int.tryParse(setJson["id"]?.toString() ?? "") ?? 0,
      tag: s(setJson["tag"] ?? setJson["computer_set_tag"]),
      name: s(setJson["name"] ?? setJson["computer_set_name"], "Computer set"),
      qrCode: s(setJson["qr_code"] ?? setJson["computer_set_qr_code"]),
      roomId: int.tryParse(setJson["room_id"]?.toString() ?? ""),
      room: s(setJson["room"] ?? setJson["room_name"]),
      members: members,
      memberMaps: maps,
    );
  }
}

/// Result of resolving a QR for maintenance flows.
sealed class MaintenanceQrResolve {
  const MaintenanceQrResolve();
}

class MaintenanceQrEquipment extends MaintenanceQrResolve {
  final Equipment equipment;
  const MaintenanceQrEquipment(this.equipment);
}

class MaintenanceQrComputerSet extends MaintenanceQrResolve {
  final ComputerSetScan computerSet;
  const MaintenanceQrComputerSet(this.computerSet);
}
