import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/iam/application/session_facade.dart';
import 'package:rumbo_mobile_application/iam/presentation/auth_screens.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/main.dart';
import 'package:rumbo_mobile_application/profiles/domain/photo_picker.dart';
import 'package:rumbo_mobile_application/profiles/infrastructure/profile_repository.dart';
import 'package:rumbo_mobile_application/profiles/presentation/profile_cubit.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/edit_profile_screen.dart';

import 'photo_picker_test.dart' show FakePhotoPicker;
import 'session_test.dart' show MemoryStorage, tokens;

// Only this server state and secure storage survive a reopening. Every HTTP
// client, facade, router and Cubit is recreated through production DI.
class ProfileServer {
  Map<String, Object?> profile = {
    'userId': '42',
    'role': 'PATIENT',
    'fullName': 'Ana Torres',
    'phoneNumber': null,
    'imageUrl': null,
  };
  Map<String, Object> preferences = {
    'avoidStairs': false,
    'simplerRoute': false,
    'voiceGuidance': false,
    'configured': false,
  };
  final requests = <http.Request>[];
  Map<String, String>? errors;
  int? failureStatus;
  int refreshes = 0;

  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/api/v1/auth/sign-up') {
      expect(jsonDecode(request.body), {
        'fullName': 'Ana Torres',
        'email': 'ana@example.test',
        'password': 'Password1',
        'role': 'PATIENT',
        'acceptedTerms': true,
      });
      return json({'id': 42}, 201);
    }
    if (path == '/api/v1/auth/sign-in') return json(tokens('login'));
    if (path == '/api/v1/auth/refresh') {
      expect(jsonDecode(request.body)['refreshToken'], 'refresh-login');
      refreshes++;
      return json(tokens('restored'));
    }
    expect(
      request.headers['Authorization'],
      'Bearer access-${refreshes == 0 ? 'login' : 'restored'}',
    );
    if (path == '/api/v1/profiles/me/preferences') {
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body.keys,
          unorderedEquals(['avoidStairs', 'simplerRoute', 'voiceGuidance']),
        );
        preferences = {...body.cast<String, Object>(), 'configured': true};
      }
      return json(preferences);
    }
    if (path == '/api/v1/profiles/me') {
      if (request.method == 'PUT') {
        if (errors != null) {
          return json({'code': 'VALIDATION_FAILED', 'errors': errors}, 400);
        }
        if (failureStatus != null) return json({}, failureStatus!);
        profile = {
          ...profile,
          ...(jsonDecode(request.body) as Map<String, dynamic>),
        };
      }
      return json(profile);
    }
    fail('Unexpected request: ${request.method} $path');
  }

  int get puts => requests.where((r) => r.method == 'PUT').length;
}

void main() {
  testWidgets('registration, preferences and profile survive a full reopening', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final server = ProfileServer();
    final picker = FakePhotoPicker();
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> close() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      serviceLocator<SessionFacade>().dispose();
      await serviceLocator.reset();
    }

    Future<void> open() async {
      await setupDependencies();
      await serviceLocator.unregister<http.Client>();
      serviceLocator.registerSingleton<http.Client>(MockClient(server.handle));
      await serviceLocator.unregister<FlutterSecureStorage>();
      serviceLocator.registerSingleton<FlutterSecureStorage>(storage);
      await serviceLocator.unregister<PhotoPicker>();
      serviceLocator.registerSingleton<PhotoPicker>(picker);
      await tester.pumpWidget(const RumboApp());
      await tester.pumpAndSettle();
    }

    Future<void> tap(String text) async {
      final target = find.text(text).last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> edit(String name, String phone) async {
      await tester.enterText(find.byType(TextFormField).at(0), name);
      await tester.enterText(find.byType(TextFormField).at(1), phone);
      await tap('Guardar');
    }

    Future<void> unchanged(Map<String, Object?> saved) async {
      if (find.byType(EditProfileScreen).evaluate().isNotEmpty) {
        final state = tester.element(find.byType(EditProfileScreen))
            .read<ProfileCubit>().state as ProfileLoaded;
        expect(state.profile!.fullName, saved['fullName']);
        expect(state.profile!.phoneNumber, saved['phoneNumber']);
        expect(state.profile!.imageUrl, saved['imageUrl']);
      }
      final loaded = await serviceLocator<ProfileRepository>().load();
      expect(loaded!.fullName, saved['fullName']);
      expect(loaded.phoneNumber, saved['phoneNumber']);
      expect(loaded.imageUrl, saved['imageUrl']);
      expect(server.profile, saved);
    }

    await open();
    addTearDown(close);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tap('Crear cuenta');
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana Torres');
    await tester.enterText(find.byType(TextFormField).at(1), 'ana@example.test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password1');
    await tester.tap(find.byType(Checkbox));
    await tap('CREAR CUENTA →');
    expect(server.requests.where(
      (r) => r.url.path == '/api/v1/auth/sign-in',
    ).length, 1);
    expect(storage.values.toString(), contains('refresh-login'));
    expect(storage.values.toString(), isNot(contains('access-login')));
    expect(find.text('Configura tus preferencias de ruta.'), findsOneWidget);
    for (final index in [0, 1]) {
      final control = find.byType(SwitchListTile).at(index);
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
    }
    expect(server.preferences, {
      'avoidStairs': true,
      'simplerRoute': true,
      'voiceGuidance': false,
      'configured': true,
    });
    await tap('Editar perfil');
    await edit('Ana Ruiz', '+51 999 111 222');
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Ana Ruiz'), findsOneWidget);
    final saved = Map<String, Object?>.of(server.profile);
    final oldSession = serviceLocator<SessionFacade>();
    final oldRepository = serviceLocator<ProfileRepository>();
    final beforeReopen = server.requests.length;
    await close();
    await open();
    expect(serviceLocator<SessionFacade>(), isNot(same(oldSession)));
    expect(serviceLocator<ProfileRepository>(), isNot(same(oldRepository)));
    expect(server.refreshes, 1);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(
      server.requests.skip(beforeReopen).any(
        (r) => r.url.path.endsWith('sign-in') || r.url.path.endsWith('sign-up'),
      ),
      isFalse,
    );
    await tap('Perfil');
    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.text('+51 999 111 222'), findsOneWidget);
    expect(find.text('ana@example.test'), findsOneWidget);
    expect(find.text('Configura tus preferencias de ruta.'), findsNothing);
    expect(
      tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .map((tile) => tile.value),
      [true, true, false],
    );

    await tap('Editar perfil');
    final beforeInvalid = server.puts;
    await edit('   ', '+51 999 111 222');
    expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);
    expect(server.puts, beforeInvalid);
    await unchanged(saved);
    await edit('Ana Nueva', 'invalid-phone');
    expect(find.text('Ingresa un número de teléfono válido.'), findsOneWidget);
    expect(server.puts, beforeInvalid);
    await unchanged(saved);

    const nameMessage = 'Revisa tu nombre completo.';
    const phoneMessage =
        'Revisa el teléfono: usa el código de país y solo dígitos.';
    // The API sends untranslated Bean Validation defaults; the app shows its own Spanish text.
    for (final fields in [
      {'fullName': 'must not be blank'},
      {'phoneNumber': 'invalid phone number'},
      {'fullName': 'size must be between 1 and 255', 'phoneNumber': 'invalid'},
    ]) {
      server.errors = fields;
      final before = server.puts;
      await edit('Ana Nueva', '+51 999 222 333');
      expect(server.puts, before + 1);
      final inputs = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(
        inputs[0].decoration!.errorText,
        fields.containsKey('fullName') ? nameMessage : null,
      );
      expect(
        inputs[1].decoration!.errorText,
        fields.containsKey('phoneNumber') ? phoneMessage : null,
      );
      for (final message in fields.values) {
        expect(find.text(message), findsNothing);
      }
      expect(inputs[0].controller!.text, 'Ana Nueva');
      expect(inputs[1].controller!.text, '+51 999 222 333');
      await unchanged(saved);
    }
    server.errors = null;
    for (final status in [400, 500]) {
      server.failureStatus = status;
      await edit('Ana Nueva', '+51 999 222 333');
      expect(
        find.text('No se pudieron guardar los cambios. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      await unchanged(saved);
    }
    await tap('Cancelar');
    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.text('+51 999 111 222'), findsOneWidget);

    picker.result = PickedPhoto(
      name: 'too-large.png',
      bytes: Uint8List(5 * 1024 * 1024 + 1)
        ..setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]),
    );
    await tap('Cambiar foto');
    final beforePhoto = server.requests.length;
    await tap('Galería');
    expect(find.text('La foto debe pesar como máximo 5 MiB.'), findsOneWidget);
    expect(server.requests.length, beforePhoto);
    await unchanged(saved);
    expect(find.text('Ana Ruiz'), findsOneWidget);
  });
}
