import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = "http://192.168.1.18:8000/api";

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

  /// Short-lived token from [verifyReporterPin]; sent as `X-Reporter-Token`.
  String? _reporterToken;

  bool get hasReporterToken => _reporterToken != null;

  Options _reporterOptions({Options? base}) {
    final options = base ?? Options();
    return options.copyWith(
      headers: {
        ...?options.headers,
        if (_reporterToken != null) "X-Reporter-Token": _reporterToken,
      },
    );
  }

  void clearReporterToken() => _reporterToken = null;

  /// Phase 1 of reporting: employee ID + 6-digit PIN.
  /// Returns the server body (`success`, `reporter`, or `code` + `message`);
  /// never throws for 4xx responses.
  Future<Map<String, dynamic>> verifyReporterPin(
    String employeeId,
    String pin,
  ) async {
    try {
      final response = await dio.post(
        "$baseUrl/reporter/verify",
        data: {"employee_id": employeeId.trim(), "pin": pin.trim()},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : <String, dynamic>{};

      if (response.statusCode == 200 && data["success"] == true) {
        _reporterToken = data["token"]?.toString();
        return data;
      }

      if (response.statusCode == 429 && data["message"] == null) {
        data["message"] = "Too many attempts. Please wait and try again.";
      }
      data["success"] = false;
      data["message"] ??= _firstValidationError(data) ??
          "Could not verify. Please try again.";
      return data;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data["message"]?.toString() : null;
      return {
        "success": false,
        "message": message ??
            (e.response == null
                ? "Network error. Check your connection and try again."
                : "Server error (${e.response?.statusCode}). Please try again."),
      };
    } catch (_) {
      return {
        "success": false,
        "message": "Network error. Check your connection and try again.",
      };
    }
  }

  /// Ends the reporter verification on the server and locally.
  Future<void> logoutReporter() async {
    final token = _reporterToken;
    _reporterToken = null;
    if (token == null) return;
    try {
      await dio.post(
        "$baseUrl/reporter/logout",
        options: Options(
          headers: {"X-Reporter-Token": token},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } catch (_) {}
  }

  /// Emails a PIN reset link. The reply is the same whether or not the ID exists.
  Future<Map<String, dynamic>> forgotReporterPin(String employeeId) async {
    try {
      final response = await dio.post(
        "$baseUrl/reporter/forgot-pin",
        data: {"employee_id": employeeId.trim()},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : <String, dynamic>{};
      final ok = response.statusCode == 200 && data["success"] == true;
      data["success"] = ok;
      if (!ok) {
        data["message"] ??= response.statusCode == 429
            ? "Too many requests. Please wait a minute and try again."
            : _firstValidationError(data) ??
                "Could not send the link. Please try again.";
      }
      return data;
    } catch (_) {
      return {
        "success": false,
        "message": "Network error. Check your connection and try again.",
      };
    }
  }

  String? _firstValidationError(Map<String, dynamic> data) {
    final errors = data["errors"];
    if (errors is! Map) return null;
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value != null) return value.toString();
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

  /// Resolves a scanned equipment QR for the reporter flow.
  /// Returns `{success: true, equipment: {...}}` or
  /// `{success: false, message: "..."}`; never throws for 4xx responses.
  Future<Map<String, dynamic>> getReportEquipmentByQr(String qr) async {
    try {
      final response = await dio.get(
        "$baseUrl/report-equipment/qr/${Uri.encodeComponent(qr.trim())}",
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {"success": false, "message": "Unexpected server response."};
    } catch (_) {
      return {
        "success": false,
        "message": "Couldn't reach the server. Check your connection.",
      };
    }
  }

  /// Reportable equipment issued to this reporter through property assignment.
  Future<List<Map<String, dynamic>>> getAssignedEquipment(
    String employeeId,
  ) async {
    try {
      final response = await dio.get(
        "$baseUrl/reporter/${Uri.encodeComponent(employeeId.trim())}/assigned-equipment",
        options: _reporterOptions(
          base: Options(validateStatus: (s) => s != null && s < 500),
        ),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

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
    List<String> equipmentDetails = const [],
    List<String> manualEquipmentNames = const [],
    List<String> manualEquipmentIssues = const [],
    List<String> manualEquipmentDetails = const [],
    List<int?> manualEquipmentRooms = const [],
    String? description,
    Map<int, File> equipmentPhotos = const {},
    List<File?> manualEquipmentPhotos = const [],
  }) async {
    final formData = FormData();

    formData.fields.add(MapEntry("employee_id", employeeId));
    formData.fields.add(MapEntry("room_id", roomId.toString()));
    if (description != null && description.trim().isNotEmpty) {
      formData.fields.add(MapEntry("description", description.trim()));
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

    for (final details in equipmentDetails) {
      formData.fields.add(MapEntry("equipment_details[]", details));
    }

    for (final details in manualEquipmentDetails) {
      formData.fields.add(MapEntry("manual_equipment_details[]", details));
    }

    for (final room in manualEquipmentRooms) {
      formData.fields.add(
        MapEntry("manual_equipment_rooms[]", room?.toString() ?? ""),
      );
    }

    // One optional photo per item: listed items keyed by equipment id,
    // manual items keyed by their position in manual_equipment_names.
    for (final entry in equipmentPhotos.entries) {
      formData.files.add(
        MapEntry(
          "equipment_photos[${entry.key}]",
          await MultipartFile.fromFile(
            entry.value.path,
            filename: basename(entry.value.path),
          ),
        ),
      );
    }

    for (var i = 0; i < manualEquipmentPhotos.length; i++) {
      final file = manualEquipmentPhotos[i];
      if (file == null) continue;
      formData.files.add(
        MapEntry(
          "manual_equipment_photos[$i]",
          await MultipartFile.fromFile(
            file.path,
            filename: basename(file.path),
          ),
        ),
      );
    }

    return await dio.post(
      "$baseUrl/submit-report",
      data: formData,
      options: _reporterOptions(
        base: Options(
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          receiveDataWhenStatusError: true,
        ),
      ),
    );
  }
}
