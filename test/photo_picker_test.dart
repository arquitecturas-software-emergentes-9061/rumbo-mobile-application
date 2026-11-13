import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/profiles/infrastructure/profile_repository.dart';
import 'package:rumbo_mobile_application/profiles/presentation/profile_cubit.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/profiles/domain/photo_picker.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/profile_photo.dart';

class FakePhotoPicker implements PhotoPicker {
  PickedPhoto? result;
  PhotoSource? source;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    this.source = source;
    return result;
  }
}

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  );

  test('validates signatures and the inclusive 5 MiB limit', () {
    expect(PickedPhoto(name: 'photo', bytes: png).validationError, isNull);
    expect(
      PickedPhoto(
        name: 'photo',
        bytes: Uint8List.fromList([255, 216, 255]),
      ).validationError,
      isNull,
    );
    expect(
      PickedPhoto(name: 'fake.png', bytes: Uint8List(10)).validationError,
      isNotNull,
    );
    final limit = Uint8List(5 * 1024 * 1024)..setRange(0, 8, png);
    expect(PickedPhoto(name: 'photo', bytes: limit).validationError, isNull);
    expect(
      PickedPhoto(
        name: 'photo',
        bytes: Uint8List(limit.length + 1),
      ).validationError,
      contains('5 MiB'),
    );
  });

  testWidgets(
    'picker cancellation, invalid photo, preview cancellation and confirmation',
    (tester) async {
      final picker = FakePhotoPicker();
      serviceLocator.registerSingleton<PhotoPicker>(picker);
      addTearDown(() => serviceLocator.reset());
      final cubit = ProfileCubit(
        ProfileRepository(
          MockClient((request) async {
            return http.Response(
              jsonEncode({
                'fullName': 'Ana Torres',
                'imageUrl': request.method == 'PUT'
                    ? 'https://example.test/new.png'
                    : null,
              }),
              200,
            );
          }),
          ApiConfiguration(baseUrl: Uri.parse('https://example.test')),
        ),
      );
      await cubit.load();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(
            home: Scaffold(body: ProfilePhoto(name: 'Ana Torres')),
          ),
        ),
      );

      Future<void> choose(String source) async {
        await tester.tap(find.text('Cambiar foto'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(source));
        await tester.pumpAndSettle();
      }

      await choose('Galería');
      expect(picker.source, PhotoSource.gallery);
      expect(find.text('Vista previa'), findsNothing);
      picker.result = PickedPhoto(name: 'bad.png', bytes: Uint8List(10));
      await choose('Cámara');
      expect(picker.source, PhotoSource.camera);
      expect(find.text('Selecciona una foto JPEG o PNG.'), findsOneWidget);
      picker.result = PickedPhoto(name: 'photo.png', bytes: png);
      await choose('Galería');
      expect(find.text('Vista previa'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
        isNull,
      );
      await choose('Galería');
      await tester.tap(find.text('Usar foto'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
        isA<NetworkImage>().having(
          (image) => image.url,
          'url',
          'https://example.test/new.png',
        ),
      );
      await choose('Quitar foto');
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
        isNull,
      );
    },
  );
}
