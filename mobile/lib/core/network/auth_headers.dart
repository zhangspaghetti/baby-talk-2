const authorizationHeaderName = 'Authorization';

String? buildBearerAuthorizationHeaderValue(String? accessToken) {
  final normalized = accessToken?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return 'Bearer $normalized';
}
