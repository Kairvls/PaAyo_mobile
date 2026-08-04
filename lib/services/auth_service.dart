import 'package:dio/dio.dart';

class AuthService {

  static const String baseUrl =
      "http://192.168.1.4:8000/api";

  final Dio dio = Dio();

  Future<Response> login() async {

    return await dio.post(

      "$baseUrl/maintenance/login",

    );

  }

}