class RoomInspectionSchedule {
  final int id;
  final String title;
  final int roomId;
  final String roomName;
  final String roomType;
  final String department;
  final String frequency;
  final String status;
  final DateTime? nextDate;
  final DateTime? lastDate;
  final String? notes;
  final List<String> checklist;

  const RoomInspectionSchedule({
    required this.id,
    required this.title,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.department,
    required this.frequency,
    required this.status,
    this.nextDate,
    this.lastDate,
    this.notes,
    this.checklist = const [],
  });

  bool get isOverdue => status == "Overdue";

  factory RoomInspectionSchedule.fromJson(Map<String, dynamic> json) {
    DateTime? d(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final rawChecks = json["checklist"];
    final checks = rawChecks is List
        ? rawChecks.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return RoomInspectionSchedule(
      id: int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      title: json["title"]?.toString() ?? "Room inspection",
      roomId: int.tryParse(json["room_id"]?.toString() ?? "") ?? 0,
      roomName: json["room_name"]?.toString() ?? "",
      roomType: json["room_type"]?.toString() ?? "",
      department: json["department"]?.toString() ?? "",
      frequency: json["frequency"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "",
      nextDate: d(json["next_date"]),
      lastDate: d(json["last_date"]),
      notes: json["notes"]?.toString(),
      checklist: checks,
    );
  }
}
