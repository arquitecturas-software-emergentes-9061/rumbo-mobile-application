import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/profiles/infrastructure/profile_repository.dart';
import 'package:rumbo_mobile_application/profiles/presentation/profile_cubit.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

void main() {
  final config = ApiConfiguration(baseUrl: Uri.parse('http://localhost:8080'));

  test(
    'loads the current visitor profile and can retry a failed request',
    () async {
      var requests = 0;
      final repository = ProfileRepository(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/profiles/me');
          if (++requests == 1) return http.Response('{}', 503);
          return http.Response(
            '{"fullName":"Ana Torres","phoneNumber":null,"imageUrl":null}',
            200,
          );
        }),
        config,
      );
      final cubit = ProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state, isA<ProfileLoadFailed>());
      await cubit.load();
      expect((cubit.state as ProfileLoaded).profile?.fullName, 'Ana Torres');
    },
  );

  test('shows a distinct state when the API cannot find the profile', () async {
    final repository = ProfileRepository(
      MockClient((_) async => http.Response('{}', 404)),
      config,
    );
    final cubit = ProfileCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect((cubit.state as ProfileLoaded).profile, isNull);
  });
}
