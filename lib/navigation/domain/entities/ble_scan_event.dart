import 'package:rumbo_mobile_application/navigation/domain/entities/ble_observation.dart';

sealed class BleScanEvent {
  const BleScanEvent();
}

class BleObservationReceived extends BleScanEvent {
  const BleObservationReceived(this.observation);

  final BleObservation observation;
}

class BleScanStatusChanged extends BleScanEvent {
  const BleScanStatusChanged(this.status, this.message);

  final String status;
  final String message;
}

class BleSampleSaved extends BleScanEvent {
  const BleSampleSaved(this.total);

  final int total;
}
