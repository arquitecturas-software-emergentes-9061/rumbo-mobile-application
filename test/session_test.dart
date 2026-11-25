import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/iam/application/session_facade.dart';
import 'package:rumbo_mobile_application/iam/application/authorized_client.dart';
import 'package:rumbo_mobile_application/iam/domain/session.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/auth_api.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/secure_session_storage.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/session_repository_impl.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

class MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

Map<String, Object> tokens([String suffix = 'new']) => {
  'userId': '42',
  'role': 'PATIENT',
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'refreshTokenExpiresAt': '2030-01-01T00:00:00Z',
};
http.Response ok(Object data) => http.Response(jsonEncode(data), 200);
SessionFacade facade(MemoryStorage memory, MockClient client) => SessionFacade(
  SessionRepositoryImpl(
    AuthApi(
      client,
      ApiConfiguration(baseUrl: Uri.parse('https://example.test')),
    ),
    SecureSessionStorage(memory),
  ),
);
Future<void> seed(MemoryStorage memory) => memory.write(
  key: SecureSessionStorage.key,
  value: jsonEncode({
    'refreshToken': 'old',
    'email': 'ana@example.test',
    'userId': '42',
  }),
);

void main() {
  test('no saved session is a first visit', () async {
    final session = facade(
      MemoryStorage(),
      MockClient((_) async => throw StateError('No request expected')),
    );
    await session.restore();
    expect((session.state as Unauthenticated).firstVisit, isTrue);
  });
  for (final status in [400, 401, 403, 499]) {
    test(
      'refresh $status expires tokens and retains email and userId',
      () async {
        final memory = MemoryStorage();
        await seed(memory);
        final session = facade(
          memory,
          MockClient((_) async => http.Response('{}', status)),
        );
        await session.restore();
        expect(session.state, isA<SessionExpired>());
        expect((session.state as SessionExpired).email, 'ana@example.test');
        final saved = await SecureSessionStorage(memory).read();
        expect(saved.refreshToken, isNull);
        expect(saved.email, 'ana@example.test');
        expect(saved.userId, '42');
        expect(session.currentAccessToken, isNull);
      },
    );
  }
  for (final configured in [true, false]) {
    test(
      'restore reads configured=$configured and persists rotated refresh',
      () async {
        final memory = MemoryStorage();
        await seed(memory);
        final session = facade(
          memory,
          MockClient(
            (request) async => request.url.path.endsWith('refresh')
                ? ok(tokens())
                : ok({'configured': configured}),
          ),
        );
        await session.restore();
        expect((session.state as Authenticated).profileConfigured, configured);
        expect(
          (await SecureSessionStorage(memory).read()).refreshToken,
          'refresh-new',
        );
        expect(memory.values.toString(), isNot(contains('access-new')));
      },
    );
  }
  for (final network in [true, false]) {
    test(
      'restore retains session on ${network ? 'network' : 'server'} failure',
      () async {
        final memory = MemoryStorage();
        await seed(memory);
        final before = Map.of(memory.values);
        final session = facade(
          memory,
          MockClient((_) async {
            if (network) throw http.ClientException('offline');
            return http.Response('{}', 503);
          }),
        );
        await session.restore();
        expect(session.state, isA<RetryableError>());
        expect(memory.values, before);
      },
    );
  }
  test(
    'preferences failure retains newly rotated token; retry uses it',
    () async {
      final memory = MemoryStorage();
      await seed(memory);
      var refreshes = 0;
      final session = facade(
        memory,
        MockClient((request) async {
          if (request.url.path.endsWith('refresh')) {
            expect(
              jsonDecode(request.body)['refreshToken'],
              refreshes++ == 0 ? 'old' : 'refresh-new',
            );
            return ok(tokens());
          }
          return refreshes == 1
              ? http.Response('{}', 503)
              : ok({'configured': true});
        }),
      );
      await session.restore();
      expect(session.state, isA<RetryableError>());
      await session.restore();
      expect(session.state, isA<Authenticated>());
    },
  );
  test('signIn persists only refresh, email and userId', () async {
    final memory = MemoryStorage();
    final session = facade(
      memory,
      MockClient(
        (r) async => r.url.path.endsWith('sign-in')
            ? ok(tokens())
            : ok({'configured': true}),
      ),
    );
    await session.signIn('ana@example.test', 'Password1');
    expect(session.currentAccessToken, 'access-new');
    expect(
      jsonDecode(memory.values[SecureSessionStorage.key]!).keys,
      unorderedEquals(['refreshToken', 'email', 'userId']),
    );
  });
  test('invalid credentials do not save anything', () async {
    final memory = MemoryStorage();
    final session = facade(
      memory,
      MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      session.signIn('ana@example.test', 'wrong'),
      throwsA(isA<SessionFailure>()),
    );
    expect(memory.values, isEmpty);
  });
  test('signUp sends PATIENT and acceptedTerms then signs in', () async {
    final paths = <String>[];
    final session = facade(
      MemoryStorage(),
      MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('sign-up')) {
          expect(jsonDecode(r.body), {
            'fullName': 'Ana',
            'email': 'ana@example.test',
            'password': 'Password1',
            'role': 'PATIENT',
            'acceptedTerms': true,
          });
          return http.Response('{"id":42}', 201);
        }
        return r.url.path.endsWith('sign-in')
            ? ok(tokens())
            : ok({'configured': false});
      }),
    );
    await session.signUp('Ana', 'ana@example.test', 'Password1');
    expect(paths, [
      '/api/v1/auth/sign-up',
      '/api/v1/auth/sign-in',
      '/api/v1/profiles/me/preferences',
    ]);
  });
  for (final fails in [false, true]) {
    test(
      'authorized 401 refresh ${fails ? 'expires' : 'retries once'}',
      () async {
        final memory = MemoryStorage();
        await seed(memory);
        final session = facade(
          memory,
          MockClient(
            (_) async => fails ? http.Response('{}', 401) : ok(tokens()),
          ),
        );
        var attempts = 0;
        final client = AuthorizedClient(
          MockClient((r) async {
            attempts++;
            if (attempts == 1) return http.Response('', 401);
            expect(r.headers['Authorization'], 'Bearer access-new');
            expect(r.body, 'payload');
            return http.Response('done', 200);
          }),
          session,
        );
        final result = client.post(
          Uri.parse('https://example.test/protected'),
          body: 'payload',
        );
        if (fails) {
          await expectLater(result, throwsA(isA<SessionFailure>()));
          expect(session.state, isA<SessionExpired>());
          expect(attempts, 1);
        } else {
          expect((await result).body, 'done');
          expect(attempts, 2);
        }
      },
    );
  }
  test('signOut clears local tokens even on network failure', () async {
    final memory = MemoryStorage();
    await seed(memory);
    final session = facade(
      memory,
      MockClient(
        (r) async => r.url.path.endsWith('refresh')
            ? ok(tokens())
            : r.url.path.endsWith('preferences')
            ? ok({'configured': true})
            : throw http.ClientException('offline'),
      ),
    );
    await session.restore();
    await expectLater(session.signOut(), throwsA(isA<http.ClientException>()));
    expect((session.state as Unauthenticated).firstVisit, isFalse);
    expect((await SecureSessionStorage(memory).read()).refreshToken, isNull);
  });
}
