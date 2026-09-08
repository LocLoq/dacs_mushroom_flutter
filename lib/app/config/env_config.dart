class EnvConfig {
  // TODO(BACKEND): đổi thành domain thật khi deploy Django server.
  static const String baseUrl = 'https://api.your-domain.com/api/v1';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
