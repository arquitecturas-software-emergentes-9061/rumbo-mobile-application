import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../shared/infrastructure/config/api_configuration.dart';
import '../domain/profile.dart';
import '../domain/photo_picker.dart';
import '../domain/route_preferences.dart';

class ProfileRepository {
  ProfileRepository(this.client, this.configuration);

  final http.Client client;
  final ApiConfiguration configuration;

  Future<Profile> uploadImage(PickedPhoto photo) async {
    final error = photo.validationError;
    if (error != null) throw ProfileImageFailure(error);
    final request =
        http.MultipartRequest(
            'PUT',
            configuration.baseUrl.resolve('/api/v1/profiles/me/image'),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              photo.bytes,
              filename: photo.name,
              contentType: http.MediaType.parse(photo.mimeType!),
            ),
          );
    return _imageResponse(
      await http.Response.fromStream(await client.send(request)),
    );
  }

  Future<Profile> deleteImage() async => _imageResponse(
    await client.delete(
      configuration.baseUrl.resolve('/api/v1/profiles/me/image'),
    ),
  );

  Profile _imageResponse(http.Response response) {
    if (response.statusCode == 200) return _parse(response);
    throw ProfileImageFailure(switch (response.statusCode) {
      413 => 'La foto debe pesar como máximo 5 MiB.',
      400 => 'La foto no es válida. Selecciona una foto JPEG o PNG.',
      502 || 503 =>
        'El almacenamiento de fotos no está disponible. Inténtalo de nuevo.',
      _ => 'No se pudo actualizar la foto. Inténtalo de nuevo.',
    });
  }

  Future<Profile?> load() async {
    final response = await client.get(
      configuration.baseUrl.resolve('/api/v1/profiles/me'),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('No se pudo cargar el perfil');
    }
    return _parse(response);
  }

  Future<Profile> update(String fullName, String? phoneNumber) async {
    final response = await client.put(
      configuration.baseUrl.resolve('/api/v1/profiles/me'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fullName': fullName, 'phoneNumber': phoneNumber}),
    );
    if (response.statusCode != 200) {
      throw StateError('No se pudo guardar el perfil');
    }
    return _parse(response);
  }

  Future<RoutePreferences> preferences() => _preferences();
  Future<RoutePreferences> savePreferences(RoutePreferences value) =>
      _preferences(value);

  Future<RoutePreferences> _preferences([RoutePreferences? value]) async {
    final uri = configuration.baseUrl.resolve(
      '/api/v1/profiles/me/preferences',
    );
    final response = await (value == null
        ? client.get(uri)
        : client.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(value.toJson()),
          ));
    if (response.statusCode != 200) {
      throw StateError('No se pudieron actualizar las preferencias');
    }
    return RoutePreferences.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Profile _parse(http.Response response) {
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return Profile(
      fullName: data['fullName'] as String,
      phoneNumber: data['phoneNumber'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

class ProfileImageFailure implements Exception {
  const ProfileImageFailure(this.message);
  final String message;
}
