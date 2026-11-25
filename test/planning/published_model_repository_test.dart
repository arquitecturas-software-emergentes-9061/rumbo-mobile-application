import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/planning/domain/published_model_repository.dart';
import 'package:rumbo_mobile_application/planning/infrastructure/published_model_mapper.dart';
import 'package:rumbo_mobile_application/planning/infrastructure/published_model_repository_impl.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';
import 'published_model_fixture.dart';

http.Response response([String version = 'v1']) => http.Response(
  jsonEncode(publishedJson(version: version)),
  200,
  headers: {
    'etag': '"map-$version"',
    'content-type': 'application/json; charset=utf-8',
  },
);
PublishedModelRepositoryImpl repository(MockClient client) =>
    PublishedModelRepositoryImpl(
      client,
      ApiConfiguration(baseUrl: Uri.parse('https://example.test')),
    );

void main() {
  test('maps all official graph elements and protects immutable lists', () {
    final model = publishedModel();
    expect(model.plans.single.name, 'Primer piso');
    expect(model.connections.single.accessibility, 'ACCESSIBLE');
    expect(model.destinations.single.name, 'Recepción');
    expect(model.walls.single.id, 'wall');
    expect(model.doors.single.wallId, 'wall');
    expect(() => model.nodes.clear(), throwsUnsupportedError);
  });
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'draft': (data) => data['status'] = 'DRAFT',
    'wrong site': (data) => data['siteId'] = 'other',
    'mixed versions': (data) =>
        data['destinations'][0]['modelVersionId'] = 'other',
    'missing node': (data) =>
        data['connections'][0]['targetNodeId'] = 'missing',
    'invalid scale': (data) => data['plans'][0]['metersPerUnit'] = 0,
    'out of bounds': (data) => data['nodes'][0]['x'] = 101,
    'duplicate node': (data) => data['nodes'][1]['id'] = 'a',
    'missing wall': (data) => data['doors'][0]['wallId'] = 'missing',
    'invalid opening': (data) => data['doors'][0]['to'] = 2,
    'missing list': (data) => data.remove('connections'),
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      final data = publishedJson();
      entry.value(data);
      expect(
        () => const PublishedModelMapper().decode(data, 'site'),
        throwsFormatException,
      );
    });
  }
  test('revalidates 304 and atomically replaces a newer version', () async {
    var calls = 0;
    final repo = repository(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/sites/site/published-map');
        calls++;
        if (calls == 1) {
          expect(request.headers['if-none-match'], isNull);
          return response();
        }
        expect(request.headers['if-none-match'], '"map-v1"');
        return calls == 2
            ? http.Response('', 304, headers: {'etag': '"map-v1"'})
            : response('v2');
      }),
    );
    final first = await repo.synchronize('site');
    expect(await repo.synchronize('site'), same(first));
    expect((await repo.synchronize('site')).versionId, 'v2');
  });
  for (final failure in [401, 403, 404, 422, 500, -1]) {
    test(
      'failure $failure clears cache instead of returning stale data',
      () async {
        var calls = 0;
        final repo = repository(
          MockClient((request) async {
            calls++;
            if (calls == 1) return response();
            if (calls == 2) {
              if (failure == -1) throw http.ClientException('offline');
              return http.Response('', failure);
            }
            expect(request.headers['if-none-match'], isNull);
            return response('v2');
          }),
        );
        await repo.synchronize('site');
        await expectLater(
          repo.synchronize('site'),
          throwsA(isA<PublishedModelFailure>()),
        );
        expect((await repo.synchronize('site')).versionId, 'v2');
      },
    );
  }
  test('rejects missing or mismatched ETag and unsolicited 304', () async {
    for (final reply in [
      http.Response(jsonEncode(publishedJson()), 200),
      http.Response(
        jsonEncode(publishedJson()),
        200,
        headers: {'etag': '"wrong"'},
      ),
      http.Response('', 304, headers: {'etag': '"map-v1"'}),
    ]) {
      await expectLater(
        repository(MockClient((_) async => reply)).synchronize('site'),
        throwsA(isA<PublishedModelFailure>()),
      );
    }
  });
  test('late response cannot replace newer cache entry', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final repo = repository(
      MockClient((request) async {
        calls++;
        if (calls == 1) return pending.future;
        if (calls == 2) return response('v2');
        expect(request.headers['if-none-match'], '"map-v2"');
        return http.Response('', 304, headers: {'etag': '"map-v2"'});
      }),
    );
    final old = repo.synchronize('site');
    final rejected = expectLater(old, throwsA(isA<PublishedModelFailure>()));
    expect((await repo.synchronize('site')).versionId, 'v2');
    pending.complete(response());
    await rejected;
    expect((await repo.synchronize('site')).versionId, 'v2');
  });
  test('logout invalidates in-flight responses', () async {
    final pending = Completer<http.Response>();
    final repo = repository(MockClient((_) => pending.future));
    final result = repo.synchronize('site');
    final rejected = expectLater(result, throwsA(isA<PublishedModelFailure>()));
    repo.clear();
    pending.complete(response());
    await rejected;
  });
  test('catalog decodes real transport shape and rejects duplicates', () async {
    var calls = 0;
    final repo = repository(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/published-sites');
        calls++;
        return http.Response(
          jsonEncode(
            List.filled(calls, {'id': 'site', 'name': 'Sede Central'}),
          ),
          200,
        );
      }),
    );
    expect((await repo.listSites()).single.name, 'Sede Central');
    await expectLater(repo.listSites(), throwsA(isA<PublishedModelFailure>()));
  });
}
