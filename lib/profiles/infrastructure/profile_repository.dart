import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../shared/infrastructure/config/api_configuration.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this.client, this.configuration);

  final http.Client client;
  final ApiConfiguration configuration;

  Future<Profile?> load() async {
    final response = await client.get(
      configuration.baseUrl.resolve('/api/v1/profiles/me'),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('No se pudo cargar el perfil');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return Profile(
      fullName: data['fullName'] as String,
      phoneNumber: data['phoneNumber'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
