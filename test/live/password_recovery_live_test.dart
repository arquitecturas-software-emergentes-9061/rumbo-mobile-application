import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rumbo_mobile_application/iam/application/password_recovery_service.dart';
import 'package:rumbo_mobile_application/iam/domain/session.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/auth_api.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/password_recovery_repository_impl.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

/// Opt in against an isolated API and a local Mailpit SMTP receiver. No external email is sent.
void main() {
  const enabled = bool.fromEnvironment('RECOVERY_LIVE_API');
  test(
    'mobile REST → API → SMTP email → reset → sign in, without mocks',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final api = AuthApi(
        client,
        ApiConfiguration(
          baseUrl: Uri.parse(
            const String.fromEnvironment(
              'RECOVERY_API_URL',
              defaultValue: 'http://127.0.0.1:18080',
            ),
          ),
        ),
      );
      final smtp = Uri.parse(
        const String.fromEnvironment(
          'RECOVERY_MAILPIT_URL',
          defaultValue: 'http://127.0.0.1:18025',
        ),
      );
      final service = PasswordRecoveryService(
        PasswordRecoveryRepositoryImpl(api),
      );
      final email =
          'recovery-${DateTime.now().microsecondsSinceEpoch}@example.test';
      await api.request(
        'auth/sign-up',
        body: {
          'email': email,
          'password': 'Rumbo2026',
          'role': 'PATIENT',
          'acceptedTerms': true,
          'fullName': 'Visitante de prueba',
        },
      );
      await service.requestLink(email);
      Map<String, dynamic>? delivered;
      for (var attempt = 0; attempt < 20 && delivered == null; attempt++) {
        final response = await client.get(smtp.resolve('/api/v1/messages'));
        expect(response.statusCode, 200);
        final messages = jsonDecode(response.body)['messages'] as List;
        for (final message in messages) {
          if ((message['To'] as List).any((to) => to['Address'] == email)) {
            final detail = await client.get(
              smtp.resolve('/api/v1/message/${message['ID']}'),
            );
            delivered =
                jsonDecode(utf8.decode(detail.bodyBytes))
                    as Map<String, dynamic>;
          }
        }
        if (delivered == null) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      expect(
        delivered,
        isNotNull,
        reason: 'Instructions must arrive through SMTP',
      );
      final link = RegExp(
        r'https?://\S+\?token=[A-Za-z0-9_-]+',
      ).firstMatch(delivered!['Text'] as String)!.group(0)!;
      await service.resetPassword(link, 'Rumbo2027');
      await expectLater(
        service.resetPassword(link, 'Rumbo2028'),
        throwsA(isA<SessionFailure>().having((f) => f.status, 'status', 400)),
      );
      await expectLater(
        api.authenticate('sign-in', {'email': email, 'password': 'Rumbo2026'}),
        throwsA(isA<SessionFailure>().having((f) => f.status, 'status', 401)),
      );
      final signedIn = await api.authenticate('sign-in', {
        'email': email,
        'password': 'Rumbo2027',
      });
      expect(signedIn.accessToken, isNotEmpty);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
