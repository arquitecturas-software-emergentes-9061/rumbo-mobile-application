import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/iam/application/authorized_client.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/profiles/domain/photo_picker.dart';
import 'package:rumbo_mobile_application/profiles/infrastructure/profile_repository.dart';
import 'package:rumbo_mobile_application/profiles/presentation/profile_cubit.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/profile_photo.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

import 'photo_picker_test.dart' show FakePhotoPicker;
import 'session_test.dart' as sessions;

void main() {
  final config = ApiConfiguration(baseUrl: Uri.parse('https://example.test'));
  final photo = PickedPhoto(
    name: 'wrong-extension.png',
    bytes: Uint8List.fromList([255, 216, 255]),
  );
  http.Response profile(String? url) => http.Response(
    jsonEncode({'fullName': 'Ana Torres', 'imageUrl': url}),
    200,
  );

  for (final mime in ['image/jpeg', 'image/png']) {
    test(
      'authorized multipart uses signature $mime and publishes server URL',
      () async {
        final memory = sessions.MemoryStorage();
        await sessions.seed(memory);
        final session = sessions.facade(
          memory,
          MockClient((_) async => sessions.ok(sessions.tokens())),
        );
        await session.refresh();
        addTearDown(session.dispose);
        final cubit = ProfileCubit(
          ProfileRepository(
            AuthorizedClient(
              MockClient((request) async {
                if (request.method == 'GET') {
                  return profile('https://example.test/old');
                }
                expect(request.method, 'PUT');
                expect(request.url.path, '/api/v1/profiles/me/image');
                expect(request.headers['Authorization'], 'Bearer access-new');
                expect(
                  request.headers['content-type'],
                  startsWith('multipart/form-data; boundary='),
                );
                final body = latin1.decode(request.bodyBytes);
                expect(
                  body,
                  contains('name="image"; filename="wrong-extension.png"'),
                );
                expect(body, contains('content-type: $mime'));
                return profile('https://example.test/new');
              }),
              session,
            ),
            config,
          ),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.uploadImage(
          mime == 'image/jpeg'
              ? photo
              : PickedPhoto(
                  name: photo.name,
                  bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
                ),
        );
        expect(
          (cubit.state as ProfileLoaded).profile?.imageUrl,
          'https://example.test/new',
        );
      },
    );
  }

  for (final deleting in [false, true]) {
    for (final status in [200, 400, 413, 502, 503, null]) {
      testWidgets(
        '${deleting ? 'DELETE' : 'upload'} $status preserves avatar on failure and shows progress',
        (tester) async {
          final response = Completer<http.Response>();
          final cubit = ProfileCubit(
            ProfileRepository(
              MockClient((request) async {
                if (request.method == 'GET') {
                  return profile('https://example.test/old');
                }
                expect(request.method, deleting ? 'DELETE' : 'PUT');
                return response.future;
              }),
              config,
            ),
          );
          addTearDown(cubit.close);
          await cubit.load();
          final previous = (cubit.state as ProfileLoaded).profile;
          serviceLocator.registerSingleton<PhotoPicker>(
            FakePhotoPicker()..result = photo,
          );
          addTearDown(serviceLocator.reset);
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: const MaterialApp(
                home: Scaffold(body: ProfilePhoto(name: 'Ana Torres')),
              ),
            ),
          );
          await tester.tap(find.text('Cambiar foto'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(deleting ? 'Quitar foto' : 'Galería'));
          if (deleting) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          } else {
            await tester.pumpAndSettle();
          }
          if (!deleting) {
            await tester.tap(find.text('Usar foto'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Cambiar foto'),
                )
                .onPressed,
            isNull,
          );
          if (status == null) {
            response.completeError(http.ClientException('offline'));
          } else {
            response.complete(
              status == 200
                  ? profile(deleting ? null : 'https://example.test/new')
                  : http.Response('{}', status),
            );
          }
          await tester.pumpAndSettle();
          final state = cubit.state as ProfileLoaded;
          final image = tester
              .widget<CircleAvatar>(find.byType(CircleAvatar))
              .foregroundImage;
          if (status == 200) {
            expect(state.imageError, isNull);
            if (deleting) {
              expect(image, isNull);
            } else {
              expect((image as NetworkImage).url, 'https://example.test/new');
            }
          } else {
            expect(state.profile, same(previous));
            expect((image as NetworkImage).url, previous!.imageUrl);
            expect(find.text(state.imageError!), findsOneWidget);
            expect(
              state.imageError,
              contains(
                status == 413
                    ? '5 MiB'
                    : status == 502 || status == 503
                    ? 'almacenamiento'
                    : status == 400
                    ? 'no es válida'
                    : 'conexión',
              ),
            );
          }
        },
      );
    }
  }
}
