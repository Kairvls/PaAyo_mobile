import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists roles from login.
/// Allowed: System Administrator and Maintenance (primary or additional).
class RoleSession {
  RoleSession._();

  static const adminRoleId = 1;
  static const maintenanceRoleId = 2;

  static const tokenKey = "token";
  static const nameKey = "name";
  static const userIdKey = "user_id";
  static const roleIdKey = "role_id";
  static const primaryRoleIdKey = "primary_role_id";
  static const roleIdsKey = "role_ids";

  static const _storage = FlutterSecureStorage();

  static const dashboardRoute = "/dashboard";

  static List<int> parseRoleIds(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => int.tryParse(e?.toString() ?? ""))
        .whereType<int>()
        .toList();
  }

  static Future<void> persistFromLogin(Map data) async {
    final user = data["user"] is Map ? data["user"] as Map : data;

    final primary = int.tryParse(
      (user["role"] ?? data["role_id"] ?? data["role"])?.toString() ?? "",
    );

    final fromRoles = parseRoleIds(user["roles"] ?? data["roles"]);
    final fromPortals = <int>[];
    final portals = data["mobile_portals"];
    if (portals is List) {
      for (final p in portals) {
        if (p is Map) {
          final id = int.tryParse(p["role_id"]?.toString() ?? "");
          if (id != null) fromPortals.add(id);
        }
      }
    }

    final allRoles = <int>{
      ?primary,
      ...fromRoles,
      ...fromPortals,
    }.toList();

    if (primary != null) {
      await _storage.write(key: primaryRoleIdKey, value: primary.toString());
    }
    if (allRoles.isNotEmpty) {
      await _storage.write(key: roleIdsKey, value: allRoles.join(","));
    }
    final active = int.tryParse(
          (user["active_role"] ?? data["active_role"])?.toString() ?? "",
        ) ??
        (allRoles.contains(maintenanceRoleId)
            ? maintenanceRoleId
            : (allRoles.contains(adminRoleId)
                ? adminRoleId
                : maintenanceRoleId));

    await _storage.write(
      key: roleIdKey,
      value: active.toString(),
    );
  }

  static Future<void> clear() async {
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: nameKey);
    await _storage.delete(key: userIdKey);
    await _storage.delete(key: roleIdKey);
    await _storage.delete(key: primaryRoleIdKey);
    await _storage.delete(key: roleIdsKey);
  }
}
