import 'package:dio/dio.dart';
import '../core/constants/api.dart';

class AuthService {
  static const String baseUrl = Api.baseUrl;

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Future<Response> login(String accessToken) async {
    return await dio.post(
      "$baseUrl/maintenance/login",
      data: {
        "access_token": accessToken,
      },
    );
  }
}
