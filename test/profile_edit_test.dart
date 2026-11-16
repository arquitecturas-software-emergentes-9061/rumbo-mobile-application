import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/profiles/infrastructure/profile_repository.dart';
import 'package:rumbo_mobile_application/profiles/presentation/profile_cubit.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

void main() {
  final config = ApiConfiguration(baseUrl: Uri.parse('http://localhost:8080'));

  for (final status in [400, 500, null]) {
    test('keeps the previous profile after update failure $status', () async {
      final repository = ProfileRepository(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"fullName":"Ana Torres"}', 200);
          }
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body), {
            'fullName': 'Ana Ruiz',
            'phoneNumber': null,
          });
          if (status == null) throw http.ClientException('offline');
          return http.Response('{}', status);
        }),
        config,
      );
      final cubit = ProfileCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final previous = cubit.state;

      await expectLater(cubit.update('Ana Ruiz', null), throwsA(anything));
      expect(cubit.state, same(previous));
    });
  }

  test('publishes the server profile after a successful update', () async {
    final repository = ProfileRepository(
      MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/profiles/me');
        return http.Response(
          '{"fullName":"Ana Ruiz","phoneNumber":"+51 999 111 222"}',
          200,
        );
      }),
      config,
    );
    final cubit = ProfileCubit(repository);
    addTearDown(cubit.close);

    await cubit.update('Ana Ruiz', '+51 999 111 222');
    final profile = (cubit.state as ProfileLoaded).profile!;
    expect(profile.fullName, 'Ana Ruiz');
    expect(profile.phoneNumber, '+51 999 111 222');
  });
}
