import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/iam/application/session_facade.dart';
import 'package:rumbo_mobile_application/iam/presentation/auth_screens.dart';
import 'session_test.dart' show MemoryStorage, facade, seed;

void main() {
  Future<void> show(
    WidgetTester tester,
    SessionFacade session, {
    bool signUp = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: AuthScreen(session: session, signUp: signUp),
    ),
  );
  Future<void> submit(WidgetTester tester, {bool signUp = false}) async {
    final button = find.widgetWithText(
      FilledButton,
      signUp ? 'CREAR CUENTA →' : 'Iniciar sesión',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('welcome has both actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Crear cuenta'), findsOneWidget);
  });
  testWidgets(
    'sign in validates empty and malformed email, then shows credentials error',
    (tester) async {
      final session = facade(
        MemoryStorage(),
        MockClient((_) async => http.Response('{}', 401)),
      );
      await show(tester, session);
      await submit(tester);
      expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'invalid');
      await submit(tester);
      expect(find.text('Ingresa un correo válido.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ana@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1');
      await submit(tester);
      expect(
        find.text('El correo o la contraseña son incorrectos.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('expired session shows notice and prefilled email', (
    tester,
  ) async {
    final memory = MemoryStorage();
    await seed(memory);
    final session = facade(
      memory,
      MockClient((_) async => http.Response('{}', 401)),
    );
    await session.restore();
    await show(tester, session);
    expect(
      find.text('Tu sesión expiró. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('ana@example.test'), findsOneWidget);
  });
  testWidgets('registration requires name, password policy and terms', (
    tester,
  ) async {
    var requests = 0;
    final session = facade(
      MemoryStorage(),
      MockClient((_) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
    await show(tester, session, signUp: true);
    await submit(tester, signUp: true);
    expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);
    expect(
      find.text('Debes aceptar los términos y la política de privacidad.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'ana@example.test',
    );
    for (final password in ['Ab1', 'password1', 'Password']) {
      await tester.enterText(find.byType(TextFormField).at(2), password);
      await submit(tester, signUp: true);
      expect(
        find.text('Usa 8 caracteres, 1 mayúscula y 1 número.'),
        findsOneWidget,
      );
    }
    await tester.enterText(find.byType(TextFormField).at(2), 'Password1');
    await submit(tester, signUp: true);
    expect(requests, 0);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await submit(tester, signUp: true);
    expect(requests, 1);
  });
}
