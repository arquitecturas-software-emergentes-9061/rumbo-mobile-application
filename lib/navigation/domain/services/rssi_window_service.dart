import '../entities/beacon_identifier.dart';
import '../entities/ble_observation.dart';
import 'rssi_analysis_service.dart';

class FilteredBeacon {
  const FilteredBeacon(
    this.id,
    this.rssi,
    this.rawDeviation,
    this.filteredDeviation,
    this.count,
    this.observedAt,
  );
  final BeaconIdentifier id;
  final double rssi, rawDeviation, filteredDeviation;
  final int count;
  final DateTime observedAt;
}

/// A time window around the existing Hampel statistics; no distance conversion.
class RssiWindowService {
  RssiWindowService({
    this.window = const Duration(seconds: 30),
    this.minimumSamples = 3,
    this.alpha = .3,
    this.maximumSamples = 120,
  }) {
    if (window <= Duration.zero ||
        minimumSamples < 1 ||
        maximumSamples < minimumSamples ||
        alpha <= 0 ||
        alpha > 1) {
      throw ArgumentError('Parámetros RSSI inválidos.');
    }
  }
  final Duration window;
  final int minimumSamples, maximumSamples;
  final double alpha;
  final _samples = <BeaconIdentifier, List<BleObservation>>{};
  final _smoothed = <BeaconIdentifier, double>{};
  final _lastAccepted = <BeaconIdentifier, DateTime>{};
  final _analysis = const RssiAnalysisService();

  static BeaconIdentifier? identity(String manufacturerData) {
    for (final part in manufacturerData.split(';')) {
      final match = RegExp(
        r'^004C:0215([0-9A-Fa-f]{42})$',
        caseSensitive: false,
      ).firstMatch(part.trim());
      if (match == null) continue;
      final bytes = match.group(1)!;
      final u = bytes.substring(0, 32);
      return BeaconIdentifier(
        uuid:
            '${u.substring(0, 8)}-${u.substring(8, 12)}-${u.substring(12, 16)}-${u.substring(16, 20)}-${u.substring(20)}',
        major: int.parse(bytes.substring(32, 36), radix: 16),
        minor: int.parse(bytes.substring(36, 40), radix: 16),
      );
    }
    return null;
  }

  bool add(
    BleObservation observation,
    DateTime now,
    Set<BeaconIdentifier> inventory,
  ) {
    expire(now);
    final id = identity(observation.manufacturerData);
    if (id == null ||
        !inventory.contains(id) ||
        observation.deviceId.isEmpty ||
        observation.rssi < -127 ||
        observation.rssi >= 0 ||
        observation.observedAt.isAfter(now.add(const Duration(seconds: 2))) ||
        now.difference(observation.observedAt) > window) {
      return false;
    }
    final last = _lastAccepted[id];
    if (last != null && !observation.observedAt.isAfter(last)) return false;
    _lastAccepted[id] = observation.observedAt;
    final values = _samples.putIfAbsent(id, () => []);
    values.add(observation);
    if (values.length > maximumSamples) values.removeAt(0);
    final robust = _analysis
        .statistics(values.map((s) => s.rssi))
        .robustMeanDbm;
    _smoothed[id] = _smoothed.containsKey(id)
        ? alpha * robust + (1 - alpha) * _smoothed[id]!
        : robust;
    return true;
  }

  void expire(DateTime now) {
    for (final id in _samples.keys.toList()) {
      _samples[id]!.removeWhere((s) => now.difference(s.observedAt) > window);
      if (_samples[id]!.isEmpty) {
        _samples.remove(id);
        _smoothed.remove(id);
        _lastAccepted.remove(id);
      }
    }
  }

  List<FilteredBeacon> snapshot(DateTime now) {
    expire(now);
    return _samples.entries.where((e) => e.value.length >= minimumSamples).map((
      e,
    ) {
      final values = e.value.map((s) => s.rssi).toList();
      final stats = _analysis.statistics(values);
      final retained = values
          .where(
            (v) =>
                (v - stats.medianDbm).abs() <=
                3 * 1.4826 * stats.medianAbsoluteDeviationDb,
          )
          .toList();
      return FilteredBeacon(
        e.key,
        _smoothed[e.key]!,
        stats.standardDeviationDb,
        _analysis.statistics(retained).standardDeviationDb,
        values.length,
        e.value.last.observedAt,
      );
    }).toList();
  }

  void clear() {
    _samples.clear();
    _smoothed.clear();
    _lastAccepted.clear();
  }
}
