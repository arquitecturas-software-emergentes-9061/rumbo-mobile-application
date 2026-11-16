import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';

/// A normalized measurement. Source and run identify provenance, not BLE hardware.
class RssiMeasurement {
  RssiMeasurement({
    required this.beaconId,
    required this.rssiDbm,
    required this.observedAt,
    required String sourceId,
    required String runId,
    required String referenceLocation,
    required String condition,
  }) : sourceId = sourceId.trim(),
       runId = runId.trim(),
       referenceLocation = referenceLocation.trim(),
       condition = condition.trim() {
    if (rssiDbm >= 0 || rssiDbm < -127) {
      throw const FormatException('RSSI inválido o no disponible.');
    }
    if (this.sourceId.isEmpty ||
        this.runId.isEmpty ||
        this.referenceLocation.isEmpty ||
        this.condition.isEmpty) {
      throw const FormatException(
        'Faltan datos de procedencia de la medición.',
      );
    }
  }

  final BeaconIdentifier beaconId;
  final int rssiDbm;
  final DateTime observedAt;
  final String sourceId;
  final String runId;
  final String referenceLocation;
  final String condition;
}
