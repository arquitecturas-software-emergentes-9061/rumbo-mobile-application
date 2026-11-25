import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/beacon_identifier.dart';
import '../../domain/entities/indoor_navigation.dart';
import '../../domain/repositories/indoor_navigation_repository.dart';
import '../../domain/services/rssi_window_service.dart';
import '../../../shared/infrastructure/config/api_configuration.dart';

class IndoorNavigationHttpRepository implements IndoorNavigationRepository {
  IndoorNavigationHttpRepository(
    this.client,
    this.configuration, {
    this.originPath = const String.fromEnvironment(
      'RUMBO_ORIGIN_PATH',
      defaultValue: '/api/v1/navigation/sites/{siteId}/position',
    ),
  });
  final http.Client client;
  final ApiConfiguration configuration;

  final String originPath;
  Future<dynamic> _request(
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = configuration.baseUrl
        .resolve(path)
        .replace(queryParameters: query);
    try {
      final response =
          await (body == null
                  ? client.get(uri)
                  : client.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String code = 'HTTP_${response.statusCode}';
        try {
          code = (jsonDecode(response.body) as Map)['code'] as String? ?? code;
        } catch (_) {
          /* Non JSON errors remain controlled. */
        }
        throw NavigationFailure(switch (response.statusCode) {
          401 => 'Tu sesión expiró.',
          403 => 'Tu cuenta no tiene acceso a la navegación de esta sede.',
          404 =>
            'No existe una ruta compatible con el origen, destino y preferencias.',
          _ => 'No se pudo consultar Navigation. Reintenta.',
        }, code: code);
      }
      return response.statusCode == 204
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on NavigationFailure {
      rethrow;
    } on FormatException {
      throw const NavigationFailure(
        'Respuesta de Navigation incompatible.',
        code: 'INVALID_RESPONSE',
      );
    } catch (_) {
      throw const NavigationFailure(
        'No se pudo conectar con Navigation.',
        code: 'NETWORK',
      );
    }
  }

  @override
  Future<Set<BeaconIdentifier>> beacons(String siteId) async {
    final rows = await _request(
      '/api/v1/navigation/sites/${Uri.encodeComponent(siteId)}/beacons',
    );
    if (rows is! List) {
      throw const NavigationFailure(
        'Inventario BLE incompatible.',
        code: 'INVALID_RESPONSE',
      );
    }
    try {
      return rows
          .cast<Map<String, dynamic>>()
          .map(
            (b) => BeaconIdentifier(
              uuid: b['uuid'] as String,
              major: b['major'] as int,
              minor: b['minor'] as int,
            ),
          )
          .toSet();
    } catch (_) {
      throw const NavigationFailure(
        'Inventario BLE incompatible.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  @override
  Future<IndoorPosition?> resolve(
    String siteId,
    List<FilteredBeacon> signals,
  ) async {
    if (originPath.isEmpty || signals.length < 2) return null;
    final data = await _request(
      originPath.replaceAll('{siteId}', Uri.encodeComponent(siteId)),
      body: {
        'observations': signals
            .map(
              (s) => {
                'uuid': s.id.uuid,
                'major': s.id.major,
                'minor': s.id.minor,
                'rssiDbm': s.rssi,
                'timestampUtc': s.observedAt.toUtc().toIso8601String(),
              },
            )
            .toList(),
      },
    );
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw const NavigationFailure(
        'Referencia espacial incompatible.',
        code: 'INVALID_RESPONSE',
      );
    }
    try {
      final x = (data['x'] as num).toDouble(),
          y = (data['y'] as num).toDouble();
      if (!x.isFinite || !y.isFinite) throw const FormatException();
      return IndoorPosition(
        siteId: data['siteId'] as String,
        floorId: data['floorId'] as String,
        nodeId: data['nodeId'] as String,
        modelVersionId: data['modelVersionId'] as String,
        planVersionId: data['planVersionId'] as String,
        x: x,
        y: y,
        observedAt: DateTime.parse(data['observedAt'] as String).toUtc(),
        reliable: data['reliable'] == true,
        metersPerUnit: (data['metersPerUnit'] as num?)?.toDouble(),
      );
    } catch (_) {
      throw const NavigationFailure(
        'Referencia espacial incompatible.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  @override
  Future<PublishedRoute> route(
    NavigationTarget target,
    IndoorPosition origin,
  ) async {
    final data = await _request(
      '/api/v1/sites/${Uri.encodeComponent(target.siteId)}/routes',
      query: {
        'from': origin.nodeId,
        'to': target.nodeId,
        ...target.preferences.query,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const NavigationFailure(
        'Respuesta de ruta incompatible.',
        code: 'INVALID_RESPONSE',
      );
    }
    try {
      final nodes = (data['nodes'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (n) => RouteNode(
              n['nodeId'] as String,
              n['floorId'] as String,
              n['planVersionId'] as String,
              (n['x'] as num).toDouble(),
              (n['y'] as num).toDouble(),
            ),
          )
          .toList();
      final links = data['links'] as List;
      if (data['siteId'] != target.siteId ||
          nodes.isEmpty ||
          nodes.first.id != origin.nodeId ||
          nodes.last.id != target.nodeId ||
          links.length != nodes.length - 1 ||
          nodes.any((n) => !n.x.isFinite || !n.y.isFinite)) {
        throw const FormatException();
      }
      for (var i = 0; i < links.length; i++) {
        if (links[i]['fromNodeId'] != nodes[i].id ||
            links[i]['toNodeId'] != nodes[i + 1].id) {
          throw const FormatException();
        }
      }
      return PublishedRoute(
        siteId: data['siteId'] as String,
        modelVersionId: data['modelVersionId'] as String,
        nodes: nodes,
        legMeters: List<double?>.generate(
          links.length,
          (i) => (links[i]['distanceMeters'] as num?)?.toDouble(),
        ),
      );
    } catch (_) {
      throw const NavigationFailure(
        'La geometría de ruta recibida es inválida.',
        code: 'INVALID_RESPONSE',
      );
    }
  }
}
