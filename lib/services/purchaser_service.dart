import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';

import '../models/maintenance_report.dart';

class PurchaserService {
  static const String baseUrl = "http://192.168.1.2:8000/api";

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

  Future<int> getAvailableCount() async {
    await _attachToken();
    final res = await dio.get("$baseUrl/purchaser/summary");
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["success"] == true) {
      return int.tryParse(data["available"]?.toString() ?? "") ?? 0;
    }

    return 0;
  }

  Future<List<MaintenanceReport>> listReports({
    String? status,
    String? search,
    bool archive = false,
    int limit = 50,
  }) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/purchaser/reports",
      queryParameters: {
        if (status != null && status.isNotEmpty) "status": status,
        if (search != null && search.trim().isNotEmpty) "search": search.trim(),
        if (archive) "archive": 1,
        "limit": limit,
      },
    );
    final data = res.data;

    if (res.statusCode == 200 && data is Map && data["reports"] is List) {
      final reports = (data["reports"] as List)
          .whereType<Map>()
          .map((e) =>
              MaintenanceReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      reports.sort((a, b) {
        final aDate = a.updatedAt ??
            a.submittedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ??
            b.submittedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final byDate = bDate.compareTo(aDate);
        if (byDate != 0) return byDate;
        return b.id.compareTo(a.id);
      });

      return reports;
    }

    return [];
  }

  Future<MaintenanceReport?> getReport(int id) async {
    await _attachToken();
    final res = await dio.get("$baseUrl/purchaser/reports/$id");
    final data = res.data;

    if (res.statusCode == 200 &&
        data is Map &&
        data["success"] == true &&
        data["report"] is Map) {
      return MaintenanceReport.fromJson(
        Map<String, dynamic>.from(data["report"] as Map),
      );
    }

    return null;
  }

  Future<Response> acceptReport(int reportId) async {
    await _attachToken();
    return dio.post("$baseUrl/purchaser/reports/$reportId/accept");
  }

  Future<Response> rejectReport({
    required int reportId,
    required String notes,
  }) async {
    await _attachToken();
    return dio.post(
      "$baseUrl/purchaser/reports/$reportId/reject",
      data: {"rejection_notes": notes},
    );
  }

  Future<Response> resolveReport({
    required int reportId,
    String? notes,
    List<int>? reportItemIds,
    File? image,
  }) async {
    await _attachToken();

    final formData = FormData();
    if (notes != null && notes.isNotEmpty) {
      formData.fields.add(MapEntry("resolution_notes", notes));
    }
    if (reportItemIds != null) {
      for (final itemId in reportItemIds) {
        formData.fields.add(MapEntry("report_item_ids[]", itemId.toString()));
      }
    }
    if (image != null) {
      formData.files.add(
        MapEntry(
          "resolution_image",
          await MultipartFile.fromFile(
            image.path,
            filename: basename(image.path),
          ),
        ),
      );
    }

    return dio.post(
      "$baseUrl/purchaser/reports/$reportId/resolve",
      data: formData,
    );
  }

  Future<Response> replaceReport({
    required int reportId,
    required String notes,
    List<int>? reportItemIds,
    File? image,
  }) async {
    await _attachToken();

    final formData = FormData.fromMap({"replacement_notes": notes});
    if (reportItemIds != null) {
      for (final itemId in reportItemIds) {
        formData.fields.add(MapEntry("report_item_ids[]", itemId.toString()));
      }
    }
    if (image != null) {
      formData.files.add(
        MapEntry(
          "replacement_image",
          await MultipartFile.fromFile(
            image.path,
            filename: basename(image.path),
          ),
        ),
      );
    }

    return dio.post(
      "$baseUrl/purchaser/reports/$reportId/replacement",
      data: formData,
    );
  }

  Future<Response> archiveReport(int reportId) async {
    await _attachToken();
    return dio.post("$baseUrl/purchaser/reports/$reportId/archive");
  }

  Future<Response> restoreReport(int reportId) async {
    await _attachToken();
    return dio.post("$baseUrl/purchaser/reports/$reportId/restore");
  }
}
