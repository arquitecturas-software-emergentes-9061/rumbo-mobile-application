import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/planning/application/published_model_sync_service.dart';
import 'package:rumbo_mobile_application/planning/domain/published_model_repository.dart';
import 'package:rumbo_mobile_application/planning/presentation/published_model_sync_cubit.dart';
import 'package:rumbo_mobile_application/planning/presentation/published_models_screen.dart';
import 'published_model_sync_cubit_test.dart' show TestModelRepository;

void main() {
  late TestModelRepository repo;
  setUp(() {
    repo = TestModelRepository();
    serviceLocator.registerFactory<PublishedModelSyncCubit>(
      () => PublishedModelSyncCubit(PublishedModelSyncService(repo)),
    );
  });
  tearDown(() => serviceLocator.reset());
  testWidgets(
    'shows official floor and destinations then removes stale model on failed resume',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: PublishedModelsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Mapas publicados'), findsOneWidget);
      expect(find.text('Primer piso'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recepción'), 250);
      expect(find.text('Recepción'), findsOneWidget);
      expect(tester.takeException(), isNull);
      repo.read = (_) async =>
          throw const PublishedModelFailure('Sin conexión');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Modelo publicado'), findsNothing);
      expect(find.text('Recepción'), findsNothing);
      expect(find.text('Reintentar sincronización'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty catalog offers retry without a map', (tester) async {
    repo.sites = [];
    await tester.pumpWidget(const MaterialApp(home: PublishedModelsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Volver a comprobar'), findsOneWidget);
    expect(find.text('Modelo publicado'), findsNothing);
  });
}
