import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart';

class ApiService {

  static const String baseUrl =
      "http://192.168.1.4:8000/api";

  final Dio dio = Dio();

  Future<Map<String, dynamic>?> verifyReporter(
    String employeeId) async {

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

    Future<Response> submitReport({
        required String employeeId,
        required int roomId,
        int? equipmentId,
        String? manualEquipmentName,
        int? issueTemplateId,
        required String description,
        required String priority,
        File? photo,
        }) async {

        FormData formData = FormData.fromMap({

            "employee_id": employeeId,

            "room_id": roomId,

            "equipment_id": equipmentId,

            "manual_equipment_name": manualEquipmentName,

            "issue_template_id": issueTemplateId,

            "description": description,

            "priority": priority,

            if (photo != null)
            "photo": await MultipartFile.fromFile(
                photo.path,
                filename: basename(photo.path),
            ),

        });

        return await dio.post(

            "$baseUrl/submit-report",

            data: formData,

            options: Options(
            contentType: "multipart/form-data",
            ),

        );
        }
}