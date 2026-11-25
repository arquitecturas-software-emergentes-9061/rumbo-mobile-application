import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/infrastructure/config/api_configuration.dart';
import '../domain/published_indoor_model.dart';
import '../domain/published_model_repository.dart';
import 'published_model_mapper.dart';

class PublishedModelRepositoryImpl implements PublishedModelRepository {
  PublishedModelRepositoryImpl(this.client, this.configuration);
  final http.Client client;
  final ApiConfiguration configuration;
  final _cache = <String, ({String etag, PublishedIndoorModel model})>{};
  final _requests = <String, int>{};
  int _epoch = 0;

  @override
  void clear() {
    _epoch++;
    _cache.clear();
    _requests.clear();
  }

  @override
  Future<List<PublishedSite>> listSites() async {
    try {
      final response = await client
          .get(configuration.baseUrl.resolve('/api/v1/published-sites'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw PublishedModelFailure(_error(response.statusCode));
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! List) throw const FormatException('Catálogo inválido.');
      final sites = body.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Sede inválida.');
        }
        return PublishedSite(
          id: PublishedModelMapper.text(value, 'id'),
          name: PublishedModelMapper.text(value, 'name'),
        );
      }).toList();
      if (sites.map((site) => site.id).toSet().length != sites.length) {
        throw const FormatException('Sedes duplicadas.');
      }
      return List.unmodifiable(sites);
    } on PublishedModelFailure {
      rethrow;
    } catch (_) {
      throw const PublishedModelFailure(
        'No se pudo cargar el catálogo de mapas publicados. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Future<PublishedIndoorModel> synchronize(String siteId) async {
    final epoch = _epoch;
    final request = (_requests[siteId] ?? 0) + 1;
    _requests[siteId] = request;
    final cached = _cache[siteId];
    try {
      final response = await client
          .get(
            configuration.baseUrl.resolve(
              '/api/v1/sites/${Uri.encodeComponent(siteId)}/published-map',
            ),
            headers: {
              'Accept': 'application/json',
              if (cached != null) 'If-None-Match': cached.etag,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (_epoch != epoch || _requests[siteId] != request) {
        throw const PublishedModelFailure('La sincronización fue reemplazada.');
      }
      if (response.statusCode == 304 &&
          cached != null &&
          response.headers['etag'] == cached.etag) {
        return cached.model;
      }
      if (response.statusCode != 200) {
        throw PublishedModelFailure(_error(response.statusCode));
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Modelo inválido.');
      }
      final model = const PublishedModelMapper().decode(body, siteId);
      final etag = response.headers['etag'];
      if (etag != '"map-${model.versionId}"') {
        throw const FormatException('La versión y su ETag no coinciden.');
      }
      _cache[siteId] = (etag: etag!, model: model);
      return model;
    } catch (error) {
      if (_epoch == epoch && _requests[siteId] == request) {
        _cache.remove(siteId);
      }
      if (error is PublishedModelFailure) rethrow;
      throw const PublishedModelFailure(
        'No se pudo comprobar la versión oficial. Sincroniza de nuevo antes de usar el mapa.',
      );
    }
  }

  String _error(int status) => switch (status) {
    401 => 'Inicia sesión para consultar el mapa publicado.',
    403 => 'Tu cuenta no tiene permiso para consultar esta sede.',
    404 => 'Esta sede ya no tiene un mapa publicado disponible.',
    422 => 'El mapa oficial contiene datos inválidos. Comunícalo a la clínica.',
    _ => 'No se pudo comprobar la versión oficial. Vuelve a sincronizar.',
  };
}
