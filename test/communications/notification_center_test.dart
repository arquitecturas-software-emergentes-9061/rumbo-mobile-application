import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/communications/application/notification_center_cubit.dart';
import 'package:rumbo_mobile_application/communications/domain/notification.dart';
import 'package:rumbo_mobile_application/communications/infrastructure/notification_http_repository.dart';
import 'package:rumbo_mobile_application/iam/domain/session.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

final _config = ApiConfiguration(baseUrl: Uri.parse('http://localhost:8080'));

Map<String, Object?> _item(String id, {bool read = false, String? type}) => {
  'id': id,
  'type': type ?? 'WELCOME',
  'channel': 'IN_APP',
  'priority': type == 'INCIDENT_REPORTED' ? 'HIGH' : 'NORMAL',
  'siteId': null,
  'title': 'Te damos la bienvenida a Rumbo',
  'message': 'Tu cuenta está lista.',
  'detail': null,
  'read': read,
  'readAt': read ? '2026-11-27T15:00:00Z' : null,
  'createdAt': '2026-11-27T14:00:00Z',
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _page(
  List<Map<String, Object?>> items, {
  int page = 0,
  int size = 20,
  int? total,
  int? unread,
}) => {
  'items': items,
  'page': page,
  'size': size,
  'total': total ?? items.length,
  'unread': unread ?? items.where((item) => item['read'] == false).length,
};

/// Fake API: keeps the read state per id like the real notification center.
class _FakeApi {
  _FakeApi(this.items);

  final List<Map<String, Object?>> items;
  final requests = <http.Request>[];
  bool down = false;
  bool expired = false;

  late final client = MockClient((request) async {
    requests.add(request);
    if (expired) throw const SessionFailure('Tu sesión expiró.');
    if (down) return http.Response('{}', 503);
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/notifications') {
      final page = int.parse(request.url.queryParameters['page']!);
      final size = int.parse(request.url.queryParameters['size']!);
      return _json(
        _page(
          items.skip(page * size).take(size).toList(),
          page: page,
          size: size,
          total: items.length,
          unread: items.where((item) => item['read'] == false).length,
        ),
      );
    }
    if (request.method == 'POST' && path.endsWith('/read-all')) {
      final unread = items.where((item) => item['read'] == false).toList();
      for (final item in unread) {
        item['read'] = true;
        item['readAt'] = '2026-11-27T15:00:00Z';
      }
      return _json({'updated': unread.length});
    }
    if (request.method == 'POST' && path.endsWith('/read')) {
      final id = path.split('/')[4];
      final match = items.where((item) => item['id'] == id);
      if (match.isEmpty) return http.Response('{}', 404);
      match.first['read'] = true;
      match.first['readAt'] ??= '2026-11-27T15:00:00Z';
      return _json(match.first);
    }
    return http.Response('{}', 500);
  });
}

void main() {
  group('NotificationHttpRepository', () {
    test('reads the center in Spanish and parses priority and text', () async {
      late http.Request seen;
      final repository = NotificationHttpRepository(
        MockClient((request) async {
          seen = request;
          return _json(
            _page([
              _item('n1', type: 'INCIDENT_REPORTED'),
              _item('n2', read: true),
            ], unread: 7),
          );
        }),
        _config,
      );

      final page = await repository.list(unreadOnly: true, page: 0, size: 2);

      expect(seen.url.path, '/api/v1/notifications');
      expect(seen.url.queryParameters, {
        'unread': 'true',
        'page': '0',
        'size': '2',
      });
      expect(seen.headers['Accept-Language'], 'es-PE');
      expect(page.items.first.priority, NotificationPriority.high);
      expect(page.items.first.title, 'Te damos la bienvenida a Rumbo');
      expect(page.items.first.isRead, isFalse);
      expect(page.items.last.isRead, isTrue);
      expect(page.unread, 7);
      expect(page.hasMore, isFalse);
    });

    test('turns an expired session into a failure that asks to sign in', () {
      final repository = NotificationHttpRepository(
        MockClient((_) async => throw const SessionFailure('expired')),
        _config,
      );

      expect(
        repository.list(),
        throwsA(
          isA<NotificationFailure>().having(
            (f) => f.sessionExpired,
            'sessionExpired',
            isTrue,
          ),
        ),
      );
    });

    test('reports a missing notification and an unreadable body', () async {
      final missing = NotificationHttpRepository(
        MockClient((_) async => http.Response('{}', 404)),
        _config,
      );
      final broken = NotificationHttpRepository(
        MockClient((_) async => http.Response('<html>', 200)),
        _config,
      );

      await expectLater(
        missing.markRead('n1'),
        throwsA(
          isA<NotificationFailure>().having((f) => f.notFound, 'notFound', true),
        ),
      );
      await expectLater(broken.list(), throwsA(isA<NotificationFailure>()));
    });
  });

  group('NotificationCenterCubit', () {
    NotificationCenterCubit cubitFor(_FakeApi api, {int pageSize = 20}) {
      final cubit = NotificationCenterCubit(
        NotificationHttpRepository(api.client, _config),
        pageSize: pageSize,
        clock: () => DateTime.utc(2026, 11, 27, 16),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('loads the first page and the next one without repeating', () async {
      final api = _FakeApi([for (var i = 0; i < 5; i++) _item('n$i')]);
      final cubit = cubitFor(api, pageSize: 2);

      await cubit.refresh();
      expect(cubit.state.items.map((n) => n.id), ['n0', 'n1']);
      expect(cubit.state.unread, 5);
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();
      await cubit.loadMore();
      await cubit.loadMore();
      expect(cubit.state.items.map((n) => n.id), ['n0', 'n1', 'n2', 'n3', 'n4']);
      expect(cubit.state.hasMore, isFalse);
    });

    test('a read shows at once and is confirmed by the API', () async {
      final api = _FakeApi([_item('n1'), _item('n2')]);
      final cubit = cubitFor(api);
      await cubit.refresh();

      await cubit.markRead('n1');

      expect(cubit.state.items.first.isRead, isTrue);
      expect(cubit.state.unread, 1);
      expect(cubit.state.pendingReads, isEmpty);
      expect(api.items.first['read'], isTrue);
    });

    test('a read that could not be sent stays read and syncs on refresh', () async {
      final api = _FakeApi([_item('n1'), _item('n2')]);
      final cubit = cubitFor(api);
      await cubit.refresh();

      api.down = true;
      await cubit.markRead('n1');
      expect(cubit.state.items.first.isRead, isTrue);
      expect(cubit.state.unread, 1);
      expect(cubit.state.pendingReads, {'n1'});

      api.down = false;
      await cubit.refresh();
      expect(api.items.first['read'], isTrue);
      expect(cubit.state.pendingReads, isEmpty);
      expect(cubit.state.items.first.isRead, isTrue);
      expect(cubit.state.unread, 1);
    });

    test('a read that is still pending keeps the badge down after a refresh', () async {
      final api = _FakeApi([_item('n1'), _item('n2')]);
      final cubit = cubitFor(api);
      await cubit.refresh();
      api.down = true;
      await cubit.markRead('n1');

      await cubit.refresh();

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.items.first.isRead, isTrue);
      expect(cubit.state.unread, 1);
    });

    test('a notification the API no longer has is removed', () async {
      final api = _FakeApi([_item('n1'), _item('n2')]);
      final cubit = cubitFor(api);
      await cubit.refresh();
      api.items.removeAt(0);

      await cubit.markRead('n1');

      expect(cubit.state.items.map((n) => n.id), ['n2']);
      expect(cubit.state.total, 1);
    });

    test('mark all read clears the badge, or restores it if it fails', () async {
      final api = _FakeApi([_item('n1'), _item('n2')]);
      final cubit = cubitFor(api);
      await cubit.refresh();

      api.down = true;
      await cubit.markAllRead();
      expect(cubit.state.unread, 2);
      expect(cubit.state.error, isNotNull);

      api.down = false;
      await cubit.markAllRead();
      expect(cubit.state.unread, 0);
      expect(cubit.state.items.every((n) => n.isRead), isTrue);
      expect(api.items.every((item) => item['read'] == true), isTrue);
    });

    test('an expired session stops the center and asks to sign in', () async {
      final api = _FakeApi([_item('n1')]);
      final cubit = cubitFor(api);
      api.expired = true;

      await cubit.refresh();

      expect(cubit.state.sessionExpired, isTrue);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.loaded, isFalse);
    });
  });
}
