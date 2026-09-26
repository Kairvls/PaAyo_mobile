import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';

import '../models/semester_inspection.dart';

class SemesterInspectionException implements Exception {
  final String message;
  final int? statusCode;

  const SemesterInspectionException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SemesterInspectionService {
  static const String baseUrl = "http://192.168.1.4:8000/api";

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

  Future<List<SemesterCampaign>> listCampaigns({
    bool includeClosed = false,
  }) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/semester-inspections",
      queryParameters: {
        if (includeClosed) "include_closed": 1,
      },
    );

    if (res.statusCode != 200 || res.data is! Map) {
      throw const SemesterInspectionException("Could not load campaigns.");
    }

    final list = res.data["campaigns"];
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((e) => SemesterCampaign.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SemesterCampaignDetail> getCampaign(
    int id, {
    String filter = "all",
    String? search,
    String? room,
  }) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/semester-inspections/$id",
      queryParameters: {
        "filter": filter,
        if (search != null && search.trim().isNotEmpty) "search": search.trim(),
        if (room != null && room.trim().isNotEmpty) "room": room.trim(),
        "limit": 500,
      },
    );

    if (res.statusCode == 404) {
      throw const SemesterInspectionException(
        "Campaign not found.",
        statusCode: 404,
      );
    }

    if (res.statusCode != 200 || res.data is! Map || res.data["campaign"] is! Map) {
      throw const SemesterInspectionException("Could not load campaign.");
    }

    final data = res.data as Map;
    final conditions = (data["conditions"] is List)
        ? (data["conditions"] as List).map((e) => e.toString()).toList()
        : const ["OK", "Malfunctioning", "Defective", "Destroyed"];
    final rooms = (data["rooms"] is List)
        ? (data["rooms"] as List).map((e) => e.toString()).toList()
        : <String>[];
    final items = (data["items"] is List)
        ? (data["items"] as List)
            .whereType<Map>()
            .map(
              (e) =>
                  SemesterInspectionItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <SemesterInspectionItem>[];

    return SemesterCampaignDetail(
      campaign: SemesterCampaign.fromJson(
        Map<String, dynamic>.from(data["campaign"] as Map),
      ),
      items: items,
      rooms: rooms,
      conditions: conditions,
    );
  }

  Future<SemesterInspectionItem> resolveByQr(int campaignId, String qr) async {
    await _attachToken();
    final res = await dio.get(
      "$baseUrl/maintenance/semester-inspections/$campaignId/by-qr",
      queryParameters: {"qr": qr},
    );

    if (res.statusCode == 404) {
      final msg = res.data is Map
          ? res.data["message"]?.toString()
          : null;
      throw SemesterInspectionException(
        msg ?? "This equipment is not part of this campaign.",
        statusCode: 404,
      );
    }

    if (res.statusCode != 200 || res.data is! Map || res.data["item"] is! Map) {
      throw const SemesterInspectionException("Could not resolve QR code.");
    }

    return SemesterInspectionItem.fromJson(
      Map<String, dynamic>.from(res.data["item"] as Map),
    );
  }

  Future<({String message, SemesterCampaignProgress progress})> inspect({
    required int campaignId,
    required int itemId,
    required String condition,
    required String findings,
    String? actionTaken,
    bool applyStatus = true,
    File? proofImage,
  }) async {
    await _attachToken();

    final form = FormData();
    form.fields.add(MapEntry("item_condition", condition));
    form.fields.add(MapEntry("item_findings", findings));
    if (actionTaken != null && actionTaken.trim().isNotEmpty) {
      form.fields.add(MapEntry("item_action_taken", actionTaken.trim()));
    }
    form.fields.add(MapEntry("apply_status", applyStatus ? "1" : "0"));

    if (proofImage != null) {
      form.files.add(
        MapEntry(
          "proof_image",
          await MultipartFile.fromFile(
            proofImage.path,
            filename: basename(proofImage.path),
          ),
        ),
      );
    }

    final res = await dio.post(
      "$baseUrl/maintenance/semester-inspections/$campaignId/inspect/$itemId",
      data: form,
    );

    if (res.statusCode != 200 || res.data is! Map) {
      final msg = res.data is Map ? res.data["message"]?.toString() : null;
      throw SemesterInspectionException(
        msg ?? "Could not save inspection.",
        statusCode: res.statusCode,
      );
    }

    final data = res.data as Map;
    return (
      message: data["message"]?.toString() ?? "Inspection saved.",
      progress: SemesterCampaignProgress.fromJson(
        data["progress"] is Map
            ? Map<String, dynamic>.from(data["progress"] as Map)
            : null,
      ),
    );
  }
}
