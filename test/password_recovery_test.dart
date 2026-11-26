import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/iam/application/password_recovery_service.dart';
import 'package:rumbo_mobile_application/iam/domain/session.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/auth_api.dart';
import 'package:rumbo_mobile_application/iam/infrastructure/password_recovery_repository_impl.dart';
import 'package:rumbo_mobile_application/iam/presentation/password_recovery_screen.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/navigation/router.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/shared/presentation/utils/ui/theme.dart';
import 'session_test.dart' show MemoryStorage, facade, seed;

const token = 'abcdefghijklmnopqrstuvwxyz0123456789_-';
PasswordRecoveryService recovery(http.Client client) => PasswordRecoveryService(
  PasswordRecoveryRepositoryImpl(
    AuthApi(
      client,
      ApiConfiguration(baseUrl: Uri.parse('https://api.example.test')),
    ),
  ),
);

void main() {
  testWidgets(
    'small display and 200 percent text remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: RumboTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: PasswordRecoveryScreen(
            confirm: true,
            recovery: recovery(MockClient((_) async => http.Response('', 204))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(
        FilledButton,
        'Guardar nueva contraseña',
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(submit.hitTestable(), findsOneWidget);
    },
  );
  test(
    'public REST requests handle empty 202/204 without authentication',
    () async {
      final requests = <http.Request>[];
      final service = recovery(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            '',
            request.url.path.endsWith('requests') ? 202 : 204,
          );
        }),
      );
      await service.requestLink(' ana@example.test ');
      await service.resetPassword(
        'https://rumbo.test/restablecer-clave?token=$token',
        'Rumbo2027',
      );
      expect(requests.map((r) => r.url.path), [
        '/api/v1/password-recovery/requests',
        '/api/v1/password-recovery/confirmations',
      ]);
      expect(
        requests.every((r) => !r.headers.containsKey('Authorization')),
        isTrue,
      );
      expect(jsonDecode(requests[0].body), {'email': 'ana@example.test'});
      expect(jsonDecode(requests[1].body), {
        'resetToken': token,
        'newPassword': 'Rumbo2027',
      });
    },
  );

  test('rejects empty, ambiguous and unsafe links locally', () {
    for (final value in [
      '',
      'short',
      'javascript:alert(1)',
      'rumbo://reset?token=$token',
      'https://rumbo.test/reset',
      'https://rumbo.test/reset?token=$token&token=other',
    ]) {
      expect(PasswordRecoveryService.tokenFromLink(value), isNull);
    }
    expect(PasswordRecoveryService.tokenFromLink(' $token '), token);
  });

  test('expired or used token shows a recovery action', () async {
    final service = recovery(
      MockClient(
        (_) async =>
            http.Response('{"code":"INVALID_PASSWORD_RESET_TOKEN"}', 400),
      ),
    );
    await expectLater(
      service.resetPassword(token, 'Rumbo2027'),
      throwsA(
        isA<SessionFailure>().having(
          (f) => f.message,
          'message',
          contains('Solicita uno nuevo'),
        ),
      ),
    );
  });

  testWidgets(
    'email validation, neutral success and disabled duplicate submission',
    (tester) async {
      final pending = Completer<http.Response>();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordRecoveryScreen(
            recovery: recovery(
              MockClient((_) {
                requests++;
                return pending.future;
              }),
            ),
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, 'Enviar instrucciones');
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Ingresa un correo válido.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'ana@example.test');
      await tester.tap(button);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(requests, 1);
      pending.complete(http.Response('', 202));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Si el correo está registrado'),
        findsOneWidget,
      );
      expect(find.text('Ya tengo un enlace'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmation validates matching passwords and clears secrets on success',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordRecoveryScreen(
            confirm: true,
            recovery: recovery(
              MockClient((_) async {
                requests++;
                return http.Response('', 204);
              }),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), token);
      await tester.enterText(find.byType(TextFormField).at(1), 'Rumbo2027');
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      var button = find.widgetWithText(
        FilledButton,
        'Guardar nueva contraseña',
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(requests, 0);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), 'Rumbo2027');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Tu contraseña se actualizó'), findsOneWidget);
    },
  );

  testWidgets('connection failure retains the form for retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryScreen(
          recovery: recovery(
            MockClient((_) async {
              throw http.ClientException('offline');
            }),
          ),
          initialEmail: 'ana@example.test',
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar instrucciones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
    expect(find.text('ana@example.test'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  for (final expired in [false, true]) {
    testWidgets(
      'recovery routes work when ${expired ? 'expired' : 'unauthenticated'}',
      (tester) async {
        final memory = MemoryStorage();
        if (expired) await seed(memory);
        final session = facade(
          memory,
          MockClient((_) async => http.Response('{}', 401)),
        );
        await session.restore();
        serviceLocator.registerSingleton<PasswordRecoveryService>(
          recovery(MockClient((_) async => http.Response('', 202))),
        );
        final router = buildRouter(session);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        router.go('/password-recovery');
        await tester.pumpAndSettle();
        expect(find.text('Recuperar acceso'), findsOneWidget);
        router.go('/password-reset');
        await tester.pumpAndSettle();
        expect(find.text('Nueva contraseña').first, findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        session.dispose();
        serviceLocator.unregister<PasswordRecoveryService>();
      },
    );
  }
}
