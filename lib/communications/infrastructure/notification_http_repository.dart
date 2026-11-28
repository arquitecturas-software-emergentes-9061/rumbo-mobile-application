import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../iam/domain/session.dart';
import '../../shared/infrastructure/config/api_configuration.dart';
import '../domain/notification.dart';
import '../domain/notification_repository.dart';

/// Adapter of the API notification center (`/api/v1/notifications`).
///
/// [client] must be the `AuthorizedClient` of IAM: it adds the access token
/// and renews the session once on a `401`, so this adapter never handles
/// tokens itself.
class NotificationHttpRepository implements NotificationRepository {
  NotificationHttpRepository(this.client, this.configuration);

  final http.Client client;
  final ApiConfiguration configuration;

  static const _headers = {
    'Accept': 'application/json',
    'Accept-Language': 'es-PE',
  };

  @override
  Future<NotificationPage> list({
    bool unreadOnly = false,
    int page = 0,
    int size = 20,
  }) async {
    final uri = configuration.baseUrl
        .resolve('/api/v1/notifications')
        .replace(
          queryParameters: {
            'unread': '$unreadOnly',
            'page': '$page',
            'size': '$size',
          },
        );
    final data = await _send(() => client.get(uri, headers: _headers));
    final items = data['items'];
    if (items is! List) throw _unreadable;
    return NotificationPage(
      items: items.map((item) => _notification(item)).toList(growable: false),
      page: _int(data['page']),
      size: _int(data['size']),
      total: _int(data['total']),
      unread: _int(data['unread']),
    );
  }

  @override
  Future<AppNotification> markRead(String id) async {
    final uri = configuration.baseUrl.resolve(
      '/api/v1/notifications/${Uri.encodeComponent(id)}/read',
    );
    return _notification(
      await _send(() => client.post(uri, headers: _headers)),
    );
  }

  @override
  Future<int> markAllRead() async {
    final uri = configuration.baseUrl.resolve(
      '/api/v1/notifications/read-all',
    );
    return _int(
      (await _send(() => client.post(uri, headers: _headers)))['updated'],
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request();
    } on SessionFailure catch (error) {
      throw NotificationFailure(error.message, sessionExpired: true);
    } on Exception {
      throw const NotificationFailure(
        'No hay conexión con Rumbo. Revisa tu internet e inténtalo de nuevo.',
      );
    }
    switch (response.statusCode) {
      case 200:
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) return data;
        } on FormatException {
          // handled below
        }
        throw _unreadable;
      case 401:
        throw const NotificationFailure(
          'Tu sesión expiró. Inicia sesión de nuevo.',
          sessionExpired: true,
        );
      case 404:
        throw const NotificationFailure(
          'Esta notificación ya no existe.',
          notFound: true,
        );
      default:
        throw const NotificationFailure(
          'No se pudieron cargar tus notificaciones. Inténtalo de nuevo.',
        );
    }
  }

  static const _unreadable = NotificationFailure(
    'La respuesta de notificaciones no es válida.',
  );

  static AppNotification _notification(Object? value) {
    if (value is! Map) throw _unreadable;
    final id = value['id'];
    final type = value['type'];
    final created = DateTime.tryParse('${value['createdAt']}');
    if (id is! String || type is! String || created == null) {
      throw _unreadable;
    }
    final readAt = value['readAt'];
    return AppNotification(
      id: id,
      type: type,
      channel: value['channel'] is String ? value['channel'] : 'IN_APP',
      priority: value['priority'] == 'HIGH'
          ? NotificationPriority.high
          : NotificationPriority.normal,
      title: value['title'] is String ? value['title'] : 'Notificación',
      message: value['message'] is String ? value['message'] : '',
      createdAt: created,
      siteId: value['siteId'] is String ? value['siteId'] : null,
      detail: value['detail'] is String ? value['detail'] : null,
      readAt: readAt is String ? DateTime.tryParse(readAt) : null,
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    throw _unreadable;
  }
}
