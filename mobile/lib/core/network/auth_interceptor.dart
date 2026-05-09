import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenProvider});
  final Future<String?> Function() tokenProvider;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
