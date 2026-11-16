import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';

void main() {
  group('AndroidBleSessionConfiguration', () {
    test('requires a reference location and condition', () {
      expect(
        () => AndroidBleSessionConfiguration(
          referenceLocation: ' ',
          condition: 'quieta',
          deviceAddresses: const ['AA:BB:CC:DD:EE:FF'],
          serviceUuids: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => AndroidBleSessionConfiguration(
          referenceLocation: 'Piso 1',
          condition: ' ',
          deviceAddresses: const ['AA:BB:CC:DD:EE:FF'],
          serviceUuids: const [],
        ),
        throwsFormatException,
      );
    });

    test('requires a real scan filter for locked-screen capture', () {
      expect(
        () => AndroidBleSessionConfiguration(
          referenceLocation: 'Piso 1',
          condition: 'quieta',
          deviceAddresses: const [],
          serviceUuids: const [],
        ),
        throwsFormatException,
      );
    });

    test('normalizes and deduplicates device addresses', () {
      final configuration = AndroidBleSessionConfiguration(
        referenceLocation: ' Recepción ',
        condition: ' Caminando ',
        deviceAddresses: const ['aa:bb:cc:dd:ee:ff', 'AA:BB:CC:DD:EE:FF'],
        serviceUuids: const [],
      );

      expect(configuration.referenceLocation, 'Recepción');
      expect(configuration.condition, 'Caminando');
      expect(configuration.deviceAddresses, ['AA:BB:CC:DD:EE:FF']);
    });

    test('rejects invalid addresses and service UUIDs', () {
      expect(
        () => AndroidBleSessionConfiguration(
          referenceLocation: 'Piso 1',
          condition: 'quieta',
          deviceAddresses: const ['beacon-1'],
          serviceUuids: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => AndroidBleSessionConfiguration(
          referenceLocation: 'Piso 1',
          condition: 'quieta',
          deviceAddresses: const [],
          serviceUuids: const ['invalid'],
        ),
        throwsFormatException,
      );
    });
  });
}
