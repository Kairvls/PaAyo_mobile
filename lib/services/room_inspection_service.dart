import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';

import '../core/constants/api.dart';
import '../models/room_inspection.dart';

class RoomInspectionException implements Exception {
  final String message;
  final int? statusCode;

  const RoomInspectionException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RoomInspectionDetail {
  final RoomInspectionSchedule schedule;
  final List<String> results;
  final List<String> checkStatuses;

  const RoomInspectionDetail({
    required this.schedule,
    required this.results,
    required this.checkStatuses,
  });
}

class RoomInspectionService {
  static const String baseUrl = Api.baseUrl;

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

  Future<List<RoomInspectionSchedule>> listSchedules({
    String? status,
    String? search,
  }) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/room-inspections",
      queryParameters: {
        if (status != null && status.isNotEmpty) "status": status,
        if (search != null && search.trim().isNotEmpty) "search": search.trim(),
        "limit": 100,
      },
    );

    if (res.statusCode != 200 || res.data is! Map) {
      throw const RoomInspectionException("Could not load room inspections.");
    }

    final list = res.data["schedules"];
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((e) => RoomInspectionSchedule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RoomInspectionDetail> getSchedule(int id) async {
    await _attachToken();
    final res = await dio.get("$baseUrl/maintenance/room-inspections/$id");

    if (res.statusCode == 404) {
      throw const RoomInspectionException(
        "Inspection not found.",
        statusCode: 404,
      );
    }

    if (res.statusCode != 200 ||
        res.data is! Map ||
        res.data["schedule"] is! Map) {
      throw const RoomInspectionException("Could not load inspection.");
    }

    final data = res.data as Map;
    final results = (data["results"] is List)
        ? (data["results"] as List).map((e) => e.toString()).toList()
        : const ["Good", "Needs Attention", "Unsafe"];
    final checkStatuses = (data["check_statuses"] is List)
        ? (data["check_statuses"] as List).map((e) => e.toString()).toList()
        : const ["Pass", "Issue", "N/A"];

    return RoomInspectionDetail(
      schedule: RoomInspectionSchedule.fromJson(
        Map<String, dynamic>.from(data["schedule"] as Map),
      ),
      results: results,
      checkStatuses: checkStatuses,
    );
  }

  Future<String> inspect({
    required int id,
    required List<String> checks,
    required String result,
    String? findings,
    String? actionTaken,
    File? proofImage,
  }) async {
    await _attachToken();

    final form = FormData.fromMap({
      for (var i = 0; i < checks.length; i++) "checks[$i]": checks[i],
      "result": result,
      if (findings != null && findings.trim().isNotEmpty)
        "findings": findings.trim(),
      if (actionTaken != null && actionTaken.trim().isNotEmpty)
        "action_taken": actionTaken.trim(),
      if (proofImage != null)
        "proof_image": await MultipartFile.fromFile(
          proofImage.path,
          filename: basename(proofImage.path),
        ),
    });

    final res = await dio.post(
      "$baseUrl/maintenance/room-inspections/$id/inspect",
      data: form,
    );

    if (res.statusCode == 422) {
      final msg = res.data is Map
          ? (res.data["message"]?.toString() ??
              res.data["errors"]?.toString() ??
              "Could not save inspection.")
          : "Could not save inspection.";
      throw RoomInspectionException(msg, statusCode: 422);
    }

    if (res.statusCode != 200 || res.data is! Map) {
      throw const RoomInspectionException("Could not save inspection.");
    }

    return res.data["message"]?.toString() ?? "Inspection recorded.";
  }
}
