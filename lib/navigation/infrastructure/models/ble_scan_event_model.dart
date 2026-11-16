import 'package:rumbo_mobile_application/navigation/domain/entities/ble_observation.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';

class BleScanEventModel {
  const BleScanEventModel(this.values);

  final Map<Object?, Object?> values;

  factory BleScanEventModel.fromPlatform(dynamic raw) {
    return BleScanEventModel(Map<Object?, Object?>.from(raw as Map));
  }

  BleScanEvent toDomain() {
    switch (values['type']) {
      case 'observation':
        return BleObservationReceived(
          BleObservation(
            deviceId: values['deviceId'] as String,
            name: values['name'] as String? ?? '',
            rssi: values['rssi'] as int,
            observedAt: DateTime.fromMillisecondsSinceEpoch(
              values['timestampMs'] as int,
              isUtc: true,
            ),
            manufacturerData: values['manufacturerData'] as String? ?? '',
          ),
        );
      case 'saved':
        return BleSampleSaved(values['total'] as int);
      case 'status':
        return BleScanStatusChanged(
          values['status'] as String? ?? 'error',
          values['message'] as String? ?? '',
        );
      default:
        throw FormatException('Evento BLE desconocido: ${values['type']}');
    }
  }
}
