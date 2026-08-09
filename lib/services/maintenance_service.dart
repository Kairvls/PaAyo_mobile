import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';

import '../models/equipment.dart';

/// Thrown when a scanned QR code has no matching equipment (HTTP 404).
class EquipmentNotFoundException implements Exception {
  final String message;
  const EquipmentNotFoundException([this.message = "Equipment not found."]);
  @override
  String toString() => message;
}

class MaintenanceService {
  static const String baseUrl = "http://192.168.1.9:8000/api";

  final Dio dio = Dio(
    BaseOptions(
      headers: {"Accept": "application/json"},
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> _attachToken() async {
    final token = await _storage.read(key: "token");
    if (token != null) {
      dio.options.headers["Authorization"] = "Bearer $token";
    }
  }

  /// GET /maintenance/equipment/{qr}
  Future<Equipment> getEquipmentByQr(String qr) async {
    await _attachToken();
    final res = await dio.get("$baseUrl/maintenance/equipment/$qr");
    final data = res.data;

    if (res.statusCode == 404 ||
        (data is Map && data["success"] == false)) {
      throw const EquipmentNotFoundException();
    }

    if (res.statusCode == 200 && data is Map && data["equipment"] != null) {
      return Equipment.fromJson(
        Map<String, dynamic>.from(data["equipment"] as Map),
      );
    }

    throw Exception("Unable to load equipment.");
  }

  /// GET /maintenance/equipments
  Future<List<Equipment>> listEquipment({String? search}) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/equipments",
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) "search": search.trim(),
      },
    );
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["equipment"] is List) {
      return (data["equipment"] as List)
          .whereType<Map>()
          .map((e) => Equipment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return [];
  }

  /// GET /maintenance/histories
  Future<List<MaintenanceRecord>> listHistory({int limit = 50}) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/histories",
      queryParameters: {"limit": limit},
    );
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["history"] is List) {
      return (data["history"] as List)
          .whereType<Map>()
          .map((e) => MaintenanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return [];
  }

  /// GET /maintenance/schedules
  Future<List<MaintenanceSchedule>> listSchedules({int limit = 50}) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/schedules",
      queryParameters: {"limit": limit},
    );
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["schedules"] is List) {
      return (data["schedules"] as List)
          .whereType<Map>()
          .map((e) =>
              MaintenanceSchedule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return [];
  }

  /// GET /maintenance/recent
  Future<MaintenanceRecent> getRecent() async {
    await _attachToken();
    final res = await dio.get("$baseUrl/maintenance/recent");
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["success"] == true) {
      return MaintenanceRecent.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception("Unable to load recent activity.");
  }

  /// GET /maintenance/history/{equipmentId}
  Future<List<MaintenanceRecord>> getHistory(int equipmentId) async {
    await _attachToken();
    final res = await dio.get("$baseUrl/maintenance/history/$equipmentId");
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["history"] is List) {
      return (data["history"] as List)
          .whereType<Map>()
          .map((e) => MaintenanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return [];
  }

  /// POST /maintenance/history
  Future<Response> storeHistory({
    required int equipmentId,
    required int personnelId,
    required String findings,
    required String status,
    String? repairAction,
    String? replacementRemarks,
    int? reportId,
    File? proofImage,
  }) async {
    await _attachToken();

    final formData = FormData.fromMap({
      "equipment_id": equipmentId,
      "personnel_id": personnelId,
      "findings": findings,
      "status": status,
      if (reportId != null) "report_id": reportId,
      if (repairAction != null && repairAction.isNotEmpty)
        "repair_action": repairAction,
      if (replacementRemarks != null && replacementRemarks.isNotEmpty)
        "replacement_remarks": replacementRemarks,
      if (proofImage != null)
        "proof_image": await MultipartFile.fromFile(
          proofImage.path,
          filename: basename(proofImage.path),
        ),
    });

    return await dio.post("$baseUrl/maintenance/history", data: formData);
  }

  /// PUT /maintenance/equipment/{id}
  Future<Response> updateEquipment({
    required int id,
    String? assetTag,
    String? brandName,
    String? model,
    String? serialNumber,
    required String conditionStatus,
    required String inventoryStatus,
    String? currentLocation,
  }) async {
    await _attachToken();
    return await dio.put(
      "$baseUrl/maintenance/equipment/$id",
      data: {
        "asset_tag": assetTag,
        "brand_name": brandName,
        "model": model,
        "serial_number": serialNumber,
        "condition_status": conditionStatus,
        "inventory_status": inventoryStatus,
        "current_location": currentLocation,
      },
    );
  }

  /// GET /maintenance/schedule/{equipmentId}
  Future<List<MaintenanceSchedule>> getSchedules(int equipmentId) async {
    await _attachToken();
    final res = await dio.get("$baseUrl/maintenance/schedule/$equipmentId");
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["schedules"] is List) {
      return (data["schedules"] as List)
          .whereType<Map>()
          .map((e) =>
              MaintenanceSchedule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // 404 (no schedule) or unexpected shape → empty list.
    return [];
  }

  /// POST /maintenance/schedule
  Future<Response> createSchedule({
    required int equipmentId,
    required String title,
    String? description,
    required String frequency,
    required DateTime nextDate,
  }) async {
    await _attachToken();

    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')}";

    return await dio.post(
      "$baseUrl/maintenance/schedule",
      data: {
        "equipment_id": equipmentId,
        "title": title,
        "description": description,
        "frequency": frequency,
        "next_date": fmt(nextDate),
      },
    );
  }

  /// PUT /maintenance/schedule/{scheduleId}
  Future<Response> updateSchedule({
    required int scheduleId,
    required String title,
    String? description,
    required String frequency,
    required DateTime nextDate,
    DateTime? lastDate,
    required String status,
  }) async {
    await _attachToken();

    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')}";

    return await dio.put(
      "$baseUrl/maintenance/schedule/$scheduleId",
      data: {
        "title": title,
        "description": description,
        "frequency": frequency,
        "next_date": fmt(nextDate),
        "last_date": lastDate != null ? fmt(lastDate) : null,
        "status": status,
      },
    );
  }
}
