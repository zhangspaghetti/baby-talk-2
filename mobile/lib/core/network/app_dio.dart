import 'package:dio/dio.dart';

class AppDio {
  AppDio._();

  static Dio create({String? baseUrl}) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        // During migration: accept all status codes to match http package behavior
        validateStatus: (status) => true,
      ),
    );
  }
}
