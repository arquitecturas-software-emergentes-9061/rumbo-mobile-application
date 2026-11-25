import 'package:flutter/foundation.dart';

class ApiConfiguration {
  const ApiConfiguration({required this.baseUrl});

  final Uri baseUrl;

  factory ApiConfiguration.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('RUMBO_API_BASE_URL');
    final value = configuredUrl.isNotEmpty
        ? configuredUrl
        : kIsWeb
        ? 'http://localhost:8080'
        : 'http://10.0.2.2:8080';
    final uri = Uri.parse(value);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(value, 'RUMBO_API_BASE_URL', 'URL inválida');
    }
    return ApiConfiguration(baseUrl: uri);
  }
}
