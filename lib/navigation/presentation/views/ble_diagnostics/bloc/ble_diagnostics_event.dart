import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';

sealed class BleDiagnosticsEvent {
  const BleDiagnosticsEvent();
}

class BleDiagnosticsStarted extends BleDiagnosticsEvent {
  const BleDiagnosticsStarted();
}

class BleDiagnosticsRefreshed extends BleDiagnosticsEvent {
  const BleDiagnosticsRefreshed();
}

class BleDiscoveryRequested extends BleDiagnosticsEvent {
  const BleDiscoveryRequested();
}

class BleCaptureRequested extends BleDiagnosticsEvent {
  const BleCaptureRequested(this.configuration);

  final AndroidBleSessionConfiguration configuration;
}

class BleScanStopRequested extends BleDiagnosticsEvent {
  const BleScanStopRequested();
}

class BleSettingsRequested extends BleDiagnosticsEvent {
  const BleSettingsRequested();
}

class BlePlatformEventReceived extends BleDiagnosticsEvent {
  const BlePlatformEventReceived(this.event);

  final BleScanEvent event;
}

class BlePlatformErrorReceived extends BleDiagnosticsEvent {
  const BlePlatformErrorReceived(this.error);

  final Object error;
}
