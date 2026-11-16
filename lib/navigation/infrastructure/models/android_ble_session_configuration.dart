import 'package:rumbo_mobile_application/navigation/domain/entities/ble_capture_session.dart';

/// Android diagnostic filters required for capture while the screen is locked.
class AndroidBleSessionConfiguration extends BleCaptureSession {
  AndroidBleSessionConfiguration({
    required super.referenceLocation,
    required super.condition,
    required Iterable<String> deviceAddresses,
    required Iterable<String> serviceUuids,
  }) : deviceAddresses = _normalizeAddresses(deviceAddresses),
       serviceUuids = _normalizeUuids(serviceUuids) {
    if (this.deviceAddresses.isEmpty && this.serviceUuids.isEmpty) {
      throw const FormatException(
        'Selecciona una baliza o indica un UUID de servicio para capturar con la pantalla bloqueada.',
      );
    }
  }

  final List<String> deviceAddresses;
  final List<String> serviceUuids;

  static final _macAddress = RegExp(r'^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$');
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static List<String> _normalizeAddresses(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.any((value) => !_macAddress.hasMatch(value))) {
      throw const FormatException('Hay una dirección BLE inválida.');
    }
    return List.unmodifiable(normalized);
  }

  static List<String> _normalizeUuids(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.any((value) => !_uuid.hasMatch(value))) {
      throw const FormatException('Hay un UUID de servicio inválido.');
    }
    return List.unmodifiable(normalized);
  }
}
