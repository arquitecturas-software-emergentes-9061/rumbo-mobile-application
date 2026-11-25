import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rumbo_mobile_application/iam/application/authorized_client.dart';
import 'package:rumbo_mobile_application/iam/application/session_facade.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/auth_api.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/secure_session_storage.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/session_repository_impl.dart';
import 'package:rumbo_mobile_application/planning/infrastructure/published_model_repository_impl.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';
import '../session_test.dart' show MemoryStorage;

// Opt-in integration against an isolated real API and PostgreSQL. No HTTP mocks.
// Mutates only the supplied test site's map: clones then publishes its graph.
class RecordingClient extends http.BaseClient {
  final http.Client delegate = http.Client();
  final statuses = <int>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    statuses.add(response.statusCode);
    return response;
  }

  @override
  void close() => delegate.close();
}

void main() {
  const enabled = bool.fromEnvironment('RUMBO_LIVE_TESTS');
  test(
    'real JWT, PostgreSQL published model, 304, draft isolation and successor replacement',
    () async {
      const email = String.fromEnvironment('RUMBO_LIVE_EMAIL');
      const password = String.fromEnvironment('RUMBO_LIVE_PASSWORD');
      const site = String.fromEnvironment('RUMBO_LIVE_SITE');
      expect(
        [email, password, site].every((value) => value.isNotEmpty),
        isTrue,
      );
      final configuration = ApiConfiguration.fromEnvironment();
      final client = RecordingClient();
      addTearDown(client.close);
      final auth = AuthApi(client, configuration);
      final session = SessionFacade(
        SessionRepositoryImpl(auth, SecureSessionStorage(MemoryStorage())),
      );
      addTearDown(session.dispose);
      await session.signIn(email, password);
      final authorized = AuthorizedClient(client, session);
      final repo = PublishedModelRepositoryImpl(authorized, configuration);
      expect((await repo.listSites()).any((entry) => entry.id == site), isTrue);
      final first = await repo.synchronize(site);
      expect(first.nodes, isNotEmpty);
      expect(first.destinations, isNotEmpty);
      expect(await repo.synchronize(site), same(first));
      expect(client.statuses.last, 304);
      final root = '/api/v1/sites/$site/maps/${first.mapId}/versions';
      final draftResponse = await authorized.post(
        configuration.baseUrl.resolve(root),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sourceVersionId': first.versionId}),
      );
      expect(draftResponse.statusCode, 201, reason: draftResponse.body);
      final draft = jsonDecode(draftResponse.body) as Map<String, dynamic>;
      expect((await repo.synchronize(site)).versionId, first.versionId);
      expect(client.statuses.last, 304);
      final publish = await authorized.patch(
        configuration.baseUrl.resolve('$root/${draft['modelVersionId']}'),
        headers: {
          'Content-Type': 'application/merge-patch+json',
          'If-Match': draftResponse.headers['etag']!,
        },
        body: jsonEncode({'status': 'PUBLISHED'}),
      );
      expect(publish.statusCode, 200, reason: publish.body);
      final current = await repo.synchronize(site);
      expect(client.statuses.last, 200);
      expect(current.versionId, draft['modelVersionId']);
      expect(current.versionId, isNot(first.versionId));
      expect(current.nodes.length, first.nodes.length);
      expect(current.connections.length, first.connections.length);
      expect(current.destinations.length, first.destinations.length);
      expect(current.plans.length, first.plans.length);
      final anonymous = await client.get(
        configuration.baseUrl.resolve('/api/v1/sites/$site/published-map'),
      );
      expect(anonymous.statusCode, 401);
      // PATIENT is the real mobile role, authenticated by the actual IAM API.
      final patientEmail =
          'sync-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
      await auth.request(
        'auth/sign-up',
        body: {
          'email': patientEmail,
          'password': password,
          'fullName': 'Visitante prueba sincronización',
          'role': 'PATIENT',
          'acceptedTerms': true,
        },
      );
      await session.signIn(patientEmail, password);
      repo.clear();
      expect((await repo.listSites()).any((entry) => entry.id == site), isTrue);
      expect((await repo.synchronize(site)).versionId, current.versionId);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
