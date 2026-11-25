import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/application/ble_diagnostics_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_observation.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_snapshot.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/ble_diagnostics_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/ble_permission_service.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_bloc.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_event.dart';

class FakeBleDiagnosticsRepository
    implements BleDiagnosticsRepository<AndroidBleSessionConfiguration> {
  final controller = StreamController<BleScanEvent>.broadcast(sync: true);
  int discoverCalls = 0;
  int captureCalls = 0;
  int stopCalls = 0;
  int advertiseCalls = 0;
  int stopAdvertiseCalls = 0;
  int exportCalls = 0;

  @override
  Stream<BleScanEvent> get events => controller.stream;

  @override
  Future<void> discover() async => discoverCalls++;

  @override
  Future<void> startCapture(
    AndroidBleSessionConfiguration configuration,
  ) async {
    captureCalls++;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> startReferenceAdvertiser(String beaconUuid) async =>
      advertiseCalls++;

  @override
  Future<void> stopReferenceAdvertiser() async => stopAdvertiseCalls++;

  @override
  Future<bool> exportCsv() async {
    exportCalls++;
    return true;
  }

  @override
  Future<BleScanSnapshot> snapshot() async => const BleScanSnapshot(
    status: 'idle',
    savedCount: 2,
    filePath: '/private/rumbo_rssi_reference.csv',
    message: '',
  );
}

class FakeBlePermissionService implements BlePermissionService {
  FakeBlePermissionService(this.granted);

  bool granted;
  bool advertiseGranted = true;

  @override
  Future<bool> requestScanPermissions() async => granted;

  @override
  Future<bool> requestAdvertisePermission() async => advertiseGranted;

  @override
  Future<void> openSettings() async {}
}

void main() {
  late FakeBleDiagnosticsRepository repository;
  late FakeBlePermissionService permissions;
  late BleDiagnosticsBloc bloc;

  setUp(() {
    repository = FakeBleDiagnosticsRepository();
    permissions = FakeBlePermissionService(true);
    bloc = BleDiagnosticsBloc(
      bleDiagnosticsFacadeService: BleDiagnosticsFacadeService(
        bleDiagnosticsRepository: repository,
        blePermissionService: permissions,
      ),
    );
  });

  tearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    await repository.controller.close();
  });

  test('does not scan when permissions are denied', () async {
    permissions.granted = false;
    final completed = bloc.stream.firstWhere(
      (state) => state.status == 'permissionsDenied',
    );

    bloc.add(const BleDiscoveryRequested());
    await completed;

    expect(repository.discoverCalls, 0);
  });

  test('does not advertise when nearby-device permission is denied', () async {
    permissions.advertiseGranted = false;

    final started = await bloc.startReferenceAdvertiser('service-uuid');

    expect(started, isFalse);
    expect(repository.advertiseCalls, 0);
  });

  test('starts the reference advertiser through the repository', () async {
    final started = await bloc.startReferenceAdvertiser('service-uuid');

    expect(started, isTrue);
    expect(repository.advertiseCalls, 1);
  });

  test('CSV export and reference advertising remain independent', () async {
    expect(await bloc.startReferenceAdvertiser('service-uuid'), isTrue);
    final exported = bloc.stream.firstWhere(
      (state) => state.message == 'CSV exportado.',
    );
    bloc.add(const BleCsvExportRequested());
    await exported;
    expect(repository.advertiseCalls, 1);
    expect(repository.exportCalls, 1);
    expect(repository.stopAdvertiseCalls, 0);

    await bloc.stopReferenceAdvertiser();
    expect(repository.stopAdvertiseCalls, 1);
    expect(repository.stopCalls, 0);
  });

  test('does not start a second capture while one is active', () async {
    final configuration = AndroidBleSessionConfiguration(
      referenceLocation: 'Piso 1',
      condition: 'quieta',
      deviceAddresses: const ['AA:BB:CC:DD:EE:FF'],
      serviceUuids: const [],
    );
    final active = bloc.stream.firstWhere(
      (state) => state.status == 'scanning',
    );

    bloc.add(BleCaptureRequested(configuration));
    bloc.add(BleCaptureRequested(configuration));
    await active;
    await Future<void>.delayed(Duration.zero);

    expect(repository.captureCalls, 1);
  });

  test(
    'forwards observations and saved count without distance conversion',
    () async {
      final observation = BleObservation(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        rssi: -71,
        observedAt: DateTime.utc(2026, 1, 1),
      );
      final saved = bloc.stream.firstWhere((state) => state.savedCount == 3);

      repository.controller.add(BleObservationReceived(observation));
      repository.controller.add(const BleSampleSaved(3));
      await saved;

      expect(bloc.state.observations.single.rssi, -71);
      expect(bloc.state.savedCount, 3);
    },
  );

  test('closing diagnostics does not stop the native capture', () async {
    await bloc.close();
    expect(repository.stopCalls, 0);
  });

  test('exports the CSV only after capture is inactive', () async {
    final active = bloc.stream.firstWhere(
      (state) => state.status == 'scanning',
    );
    repository.controller.add(const BleScanStatusChanged('scanning', ''));
    await active;
    bloc.add(const BleCsvExportRequested());
    await Future<void>.delayed(Duration.zero);
    expect(repository.exportCalls, 0);

    final idle = bloc.stream.firstWhere((state) => state.status == 'idle');
    repository.controller.add(const BleScanStatusChanged('idle', ''));
    await idle;
    final exported = bloc.stream.firstWhere(
      (state) => state.message == 'CSV exportado.',
    );
    bloc.add(const BleCsvExportRequested());
    await exported;
    expect(repository.exportCalls, 1);
  });
}
