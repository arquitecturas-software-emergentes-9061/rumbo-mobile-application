import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_measurement.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/rssi_measurement_csv_model.dart';

class RssiNormalizationResult {
  const RssiNormalizationResult({
    required this.measurements,
    required this.unresolvedCount,
  });

  final List<RssiMeasurement> measurements;
  final int unresolvedCount;
}

/// Reads Fase 1 Android CSV without equating a device address to beacon identity.
class AndroidPhase1RssiCsvAdapter {
  const AndroidPhase1RssiCsvAdapter();

  RssiNormalizationResult normalize(
    String csv, {
    required String sourceId,
    required String runId,
    Map<String, BeaconIdentifier> beaconByDeviceAddress = const {},
  }) {
    const columns = [
      'timestamp_utc',
      'device_id',
      'advertised_name',
      'manufacturer_data',
      'rssi_dbm',
      'reference_location',
      'condition',
    ];
    final measurements = <RssiMeasurement>[];
    var unresolved = 0;
    for (final row in const RssiMeasurementCsvModel().records(csv, columns)) {
      final address = row['device_id']!.toUpperCase();
      final fromPayload = _iBeaconFromManufacturerData(
        row['manufacturer_data']!,
      );
      final fromInventory = beaconByDeviceAddress[address];
      if (fromPayload != null &&
          fromInventory != null &&
          fromPayload != fromInventory) {
        throw FormatException('Identidad contradictoria para $address.');
      }
      final beacon = fromPayload ?? fromInventory;
      if (beacon == null) {
        unresolved++;
        continue;
      }
      measurements.add(
        RssiMeasurement(
          beaconId: beacon,
          rssiDbm: int.parse(row['rssi_dbm']!),
          observedAt: DateTime.parse(row['timestamp_utc']!).toUtc(),
          referenceLocation: row['reference_location']!,
          condition: row['condition']!,
          sourceId: sourceId,
          runId: runId,
        ),
      );
    }
    return RssiNormalizationResult(
      measurements: List.unmodifiable(measurements),
      unresolvedCount: unresolved,
    );
  }

  BeaconIdentifier? _iBeaconFromManufacturerData(String value) {
    for (final part in value.split(';')) {
      final match = RegExp(
        r'^004C:0215([0-9A-Fa-f]{42})$',
      ).firstMatch(part.trim());
      if (match == null) continue;
      final bytes = match.group(1)!;
      final uuidHex = bytes.substring(0, 32).toLowerCase();
      return BeaconIdentifier(
        uuid:
            '${uuidHex.substring(0, 8)}-${uuidHex.substring(8, 12)}-'
            '${uuidHex.substring(12, 16)}-${uuidHex.substring(16, 20)}-'
            '${uuidHex.substring(20)}',
        major: int.parse(bytes.substring(32, 36), radix: 16),
        minor: int.parse(bytes.substring(36, 40), radix: 16),
      );
    }
    return null;
  }
}
