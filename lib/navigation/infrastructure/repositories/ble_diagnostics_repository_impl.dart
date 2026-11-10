import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_snapshot.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/ble_diagnostics_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ble_platform_data_provider.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/ble_capture_request.dart';

class BleDiagnosticsRepositoryImpl
    implements BleDiagnosticsRepository<AndroidBleSessionConfiguration> {
  const BleDiagnosticsRepositoryImpl({required this.blePlatformDataProvider});

  final BlePlatformDataProvider blePlatformDataProvider;

  @override
  Stream<BleScanEvent> get events =>
      blePlatformDataProvider.events.map((model) => model.toDomain());

  @override
  Future<void> discover() => blePlatformDataProvider.discover();

  @override
  Future<void> startCapture(AndroidBleSessionConfiguration configuration) {
    return blePlatformDataProvider.startCapture(
      BleCaptureRequest.fromConfiguration(configuration),
    );
  }

  @override
  Future<void> stop() => blePlatformDataProvider.stop();

  @override
  Future<void> startReferenceAdvertiser(String beaconUuid) =>
      blePlatformDataProvider.startReferenceAdvertiser(beaconUuid);

  @override
  Future<void> stopReferenceAdvertiser() =>
      blePlatformDataProvider.stopReferenceAdvertiser();

  @override
  Future<BleScanSnapshot> snapshot() async {
    final model = await blePlatformDataProvider.snapshot();
    return model.toDomain();
  }
}
