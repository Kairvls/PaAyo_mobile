class UserModel {
  final int id;
  final String name;
  final String email;
  final int roleId;
  final List<int> roleIds;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.roleId,
    this.roleIds = const [],
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final user = json["user"] is Map
        ? Map<String, dynamic>.from(json["user"] as Map)
        : json;

    final rolesRaw = user["roles"] ?? json["roles"];
    final roleIds = rolesRaw is List
        ? rolesRaw
            .map((e) => int.tryParse(e?.toString() ?? ""))
            .whereType<int>()
            .toList()
        : <int>[];

    final primary = int.tryParse(user["role"]?.toString() ?? "") ?? 0;

    return UserModel(
      id: int.tryParse(user["id"]?.toString() ?? "") ?? 0,
      name: user["name"]?.toString() ?? "",
      email: user["email"]?.toString() ?? "",
      roleId: primary,
      roleIds: roleIds.isNotEmpty
          ? roleIds
          : (primary > 0 ? [primary] : const []),
      token: json["token"]?.toString() ?? "",
    );
  }
}
