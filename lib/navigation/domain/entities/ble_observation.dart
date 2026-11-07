/// A raw BLE advertisement observation. RSSI is signal strength, not distance.
class BleObservation {
  const BleObservation({
    required this.deviceId,
    required this.rssi,
    required this.observedAt,
    this.name = '',
    this.manufacturerData = '',
  });

  final String deviceId;
  final String name;
  final int rssi;
  final DateTime observedAt;
  final String manufacturerData;
}
