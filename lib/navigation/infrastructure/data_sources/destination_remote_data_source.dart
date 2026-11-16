import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/destination_model.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

class DestinationDirectoryException implements Exception {
  const DestinationDirectoryException(this.message);
  final String message;

  @override
  String toString() => 'DestinationDirectoryException: $message';
}

/// Consume el directorio de destinos del Web Services API.
class DestinationRemoteDataSource implements DestinationDataSource {
  DestinationRemoteDataSource({
    required http.Client client,
    required ApiConfiguration configuration,
    this.path = '/api/v1/navigation/destinations',
  })  : _client = client,
        _configuration = configuration;

  final http.Client _client;
  final ApiConfiguration _configuration;

  /// Ruta supuesta: confirmar con el contrato de la API (PR-215).
  final String path;

  @override
  Future<List<DestinationModel>> fetchDirectory() async {
    final uri = _configuration.baseUrl.resolve(path);
    final http.Response response;
    try {
      response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    } catch (_) {
      throw const DestinationDirectoryException('No se pudo contactar al servidor.');
    }
    if (response.statusCode != 200) {
      throw DestinationDirectoryException('El directorio respondió ${response.statusCode}.');
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final items = body is List ? body : (body as Map<String, dynamic>)['items'] as List;
      return items
          .cast<Map<String, dynamic>>()
          .map(DestinationModel.fromJson)
          .toList();
    } catch (_) {
      throw const DestinationDirectoryException('El directorio tiene un formato inesperado.');
    }
  }
}
