import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/infrastructure/config/api_configuration.dart';
import '../domain/session.dart';

class AuthApi {
  AuthApi(this.client, this.configuration);
  final http.Client client;
  final ApiConfiguration configuration;

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    bool get = false,
  }) async {
    final uri = configuration.baseUrl.resolve('/api/v1/$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response = await (get
        ? client.get(uri, headers: headers)
        : client.post(uri, headers: headers, body: jsonEncode(body ?? {})));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'No se pudo completar la solicitud. Inténtalo de nuevo.';
      try {
        final problem = jsonDecode(utf8.decode(response.bodyBytes));
        if (problem is Map && problem['message'] is String) {
          message = problem['message'] as String;
        }
      } on FormatException {
        /* An upstream error need not contain JSON. */
      }
      throw SessionFailure(message, status: response.statusCode);
    }
    return response.body.isEmpty
        ? {}
        : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Session> authenticate(String action, Map<String, dynamic> body) async {
    final data = await request('auth/$action', body: body);
    return Session(
      userId: data['userId'].toString(),
      role: data['role'] as String,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        data['refreshTokenExpiresAt'] as String,
      ),
    );
  }
}
