import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_measurement.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/android/android_phase1_rssi_csv_adapter.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/rssi_measurement_csv_model.dart';

void main() {
  const codec = RssiMeasurementCsvModel();
  final beacon = BeaconIdentifier(
    uuid: '00112233-4455-6677-8899-aabbccddeeff',
    major: 42,
    minor: 7,
  );

  test('canonical CSV preserves a logical ID across sources', () {
    final android = RssiMeasurement(
      beaconId: beacon,
      rssiDbm: -71,
      observedAt: DateTime.utc(2026, 1, 1, 10),
      sourceId: 'pixel-device',
      runId: 'run-android',
      referenceLocation: 'Piso 1, recepción',
      condition: 'quieta',
    );
    final ios = RssiMeasurement(
      beaconId: beacon,
      rssiDbm: -76,
      observedAt: DateTime.utc(2026, 1, 1, 11),
      sourceId: 'iphone-device',
      runId: 'run-ios',
      referenceLocation: 'Piso 1, recepción',
      condition: 'quieta',
    );
    final decoded = codec.decode(codec.encode([android, ios]));
    expect(decoded.map((sample) => sample.beaconId), [beacon, beacon]);
    expect(decoded.map((sample) => sample.sourceId), [
      'pixel-device',
      'iphone-device',
    ]);
    expect(decoded.map((sample) => sample.rssiDbm), [-71, -76]);
  });

  test('converts Apple manufacturer payload, ignores unresolved addresses', () {
    const legacy =
        'timestamp_utc,device_id,advertised_name,manufacturer_data,rssi_dbm,reference_location,condition\n'
        '"2026-01-01T10:00:00.000Z","AA:BB:CC:DD:EE:FF","Beacon",'
        '"004C:021500112233445566778899AABBCCDDEEFF002A0007C5",'
        '"-71","Piso 1, recepción","quieta"\n'
        '"2026-01-01T10:00:01.000Z","11:22:33:44:55:66","Other",'
        '"","-80","Piso 1, recepción","quieta"\n';
    final result = const AndroidPhase1RssiCsvAdapter().normalize(
      legacy,
      sourceId: 'pixel-device',
      runId: 'run-1',
    );
    expect(result.measurements.single.beaconId, beacon);
    expect(result.unresolvedCount, 1);
  });

  test('does not infer a logical ID from a device address alone', () {
    const legacy =
        'timestamp_utc,device_id,advertised_name,manufacturer_data,rssi_dbm,reference_location,condition\n'
        '"2026-01-01T10:00:00.000Z","AA:BB:CC:DD:EE:FF","",'
        '"","-71","A","quieta"\n';
    final unresolved = const AndroidPhase1RssiCsvAdapter().normalize(
      legacy,
      sourceId: 'device-1',
      runId: 'run-1',
    );
    expect(unresolved.measurements, isEmpty);
    expect(unresolved.unresolvedCount, 1);

    final mapped = const AndroidPhase1RssiCsvAdapter().normalize(
      legacy,
      sourceId: 'device-1',
      runId: 'run-1',
      beaconByDeviceAddress: {'AA:BB:CC:DD:EE:FF': beacon},
    );
    expect(mapped.measurements.single.beaconId, beacon);
  });

  test('rejects conflicting inventory and payload identities', () {
    const legacy =
        'timestamp_utc,device_id,advertised_name,manufacturer_data,rssi_dbm,reference_location,condition\n'
        '"2026-01-01T10:00:00.000Z","AA:BB:CC:DD:EE:FF","",'
        '"004C:021500112233445566778899AABBCCDDEEFF002A0007C5",'
        '"-71","A","quieta"\n';
    expect(
      () => const AndroidPhase1RssiCsvAdapter().normalize(
        legacy,
        sourceId: 'device-1',
        runId: 'run-1',
        beaconByDeviceAddress: {
          'AA:BB:CC:DD:EE:FF': BeaconIdentifier(
            uuid: beacon.uuid,
            major: 42,
            minor: 8,
          ),
        },
      ),
      throwsFormatException,
    );
  });
}
