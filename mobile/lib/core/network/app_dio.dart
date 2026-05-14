import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class AppDio {
  AppDio._();

  static final CookieJar cookieJar = CookieJar();

  static Dio create({String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        // During migration: accept all status codes to match http package behavior
        validateStatus: (status) => true,
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    return dio;
  }
}
