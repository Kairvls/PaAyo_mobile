import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = "http://192.168.1.2:8000/api";

  final Dio dio = Dio(
    BaseOptions(
      headers: {
        "Accept": "application/json",
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<void> loadToken() async {
    final token = await storage.read(
      key: "token",
    );

    if (token != null) {
      dio.options.headers["Authorization"] = "Bearer $token";
    }
  }

  Future<Map<String, dynamic>?> verifyReporter(String employeeId) async {
    try {
      final response = await dio.get(
        "$baseUrl/reporter/$employeeId",
      );

      print("STATUS: ${response.statusCode}");
      print("DATA: ${response.data}");

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      print("ERROR:");
      print(e);
    }

    return null;
  }

  Future<List<dynamic>> getRooms() async {
    final response = await dio.get(
      "$baseUrl/rooms",
    );

    return response.data;
  }

  Future<List<dynamic>> getEquipment(int roomId) async {
    try {
      final response = await dio.get(
        "$baseUrl/equipment/$roomId",
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print(e);
    }

    return [];
  }

  Future<List<dynamic>> getSuggestedIssues(
    int equipmentId,
  ) async {
    try {
      final response = await dio.get(
        "$baseUrl/suggested-issues/$equipmentId",
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print(e);
    }

    return [];
  }

  Future<List<dynamic>> getGlobalSuggestedIssues() async {
    try {
      final response = await dio.get(
        "$baseUrl/global-suggested-issues",
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print(e);
    }

    return [];
  }

  /// Multipart submit matching web one-to-many reporting.
  Future<Response> submitReport({
    required String employeeId,
    required int roomId,
    List<int> equipmentIds = const [],
    List<String> equipmentIssues = const [],
    List<String> manualEquipmentNames = const [],
    List<String> manualEquipmentIssues = const [],
    String? description,
    required String priority,
    String? preferredActionDate,
    File? photo,
  }) async {
    final formData = FormData();

    formData.fields.add(MapEntry("employee_id", employeeId));
    formData.fields.add(MapEntry("room_id", roomId.toString()));
    formData.fields.add(MapEntry("priority", priority));

    if (description != null && description.trim().isNotEmpty) {
      formData.fields.add(MapEntry("description", description.trim()));
    }

    if (preferredActionDate != null && preferredActionDate.isNotEmpty) {
      formData.fields.add(
        MapEntry("preferred_action_date", preferredActionDate),
      );
    }

    for (final id in equipmentIds) {
      formData.fields.add(MapEntry("equipment_ids[]", id.toString()));
    }

    for (final issue in equipmentIssues) {
      formData.fields.add(MapEntry("equipment_issues[]", issue));
    }

    for (final name in manualEquipmentNames) {
      formData.fields.add(MapEntry("manual_equipment_names[]", name));
    }

    for (final issue in manualEquipmentIssues) {
      formData.fields.add(MapEntry("manual_equipment_issues[]", issue));
    }

    if (photo != null) {
      formData.files.add(
        MapEntry(
          "photo",
          await MultipartFile.fromFile(
            photo.path,
            filename: basename(photo.path),
          ),
        ),
      );
    }

    return await dio.post(
      "$baseUrl/submit-report",
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        receiveDataWhenStatusError: true,
      ),
    );
  }
}
