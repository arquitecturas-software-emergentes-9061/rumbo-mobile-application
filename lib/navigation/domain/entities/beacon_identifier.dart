/// Logical iBeacon identity shared by native adapters and RSSI analysis.
class BeaconIdentifier {
  BeaconIdentifier({
    required String uuid,
    required this.major,
    required this.minor,
  }) : uuid = uuid.toLowerCase() {
    if (!_uuidPattern.hasMatch(this.uuid) ||
        major < 0 ||
        major > 65535 ||
        minor < 0 ||
        minor > 65535) {
      throw const FormatException('Identificador de baliza inválido.');
    }
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final String uuid;
  final int major;
  final int minor;

  @override
  bool operator ==(Object other) =>
      other is BeaconIdentifier &&
      uuid == other.uuid &&
      major == other.major &&
      minor == other.minor;

  @override
  int get hashCode => Object.hash(uuid, major, minor);

  @override
  String toString() => '$uuid/$major/$minor';
}
