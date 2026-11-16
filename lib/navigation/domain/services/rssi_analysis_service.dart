import 'dart:math' as math;

import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_analysis.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_measurement.dart';

class RssiGroupKey {
  const RssiGroupKey({
    required this.sourceId,
    required this.runId,
    required this.referenceLocation,
    required this.condition,
    required this.beaconId,
  });

  final String sourceId;
  final String runId;
  final String referenceLocation;
  final String condition;
  final BeaconIdentifier beaconId;

  @override
  bool operator ==(Object other) =>
      other is RssiGroupKey &&
      sourceId == other.sourceId &&
      runId == other.runId &&
      referenceLocation == other.referenceLocation &&
      condition == other.condition &&
      beaconId == other.beaconId;

  @override
  int get hashCode =>
      Object.hash(sourceId, runId, referenceLocation, condition, beaconId);
}

/// Exploratory signal statistics; these values are not spatial confidence.
class RssiAnalysisService {
  const RssiAnalysisService();

  RssiStatistics statistics(Iterable<int> readings) {
    final values = readings.map((value) => value.toDouble()).toList()..sort();
    if (values.isEmpty) throw const FormatException('No hay lecturas RSSI.');
    final mean = _mean(values);
    final median = _median(values);
    final deviations = values.map((value) => (value - median).abs()).toList()
      ..sort();
    final mad = _median(deviations);
    // Hampel rule. With zero MAD only readings equal to the median remain.
    final limit = 3 * 1.4826 * mad;
    final retained = values
        .where((value) => (value - median).abs() <= limit)
        .toList();
    final variance =
        values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return RssiStatistics(
      count: values.length,
      meanDbm: mean,
      medianDbm: median,
      robustMeanDbm: _mean(retained),
      standardDeviationDb: math.sqrt(variance),
      medianAbsoluteDeviationDb: mad,
      outlierCount: values.length - retained.length,
    );
  }

  Map<RssiGroupKey, RssiStatistics> summarize(
    Iterable<RssiMeasurement> measurements,
  ) {
    final groups = <RssiGroupKey, List<int>>{};
    for (final sample in measurements) {
      final key = RssiGroupKey(
        sourceId: sample.sourceId,
        runId: sample.runId,
        referenceLocation: sample.referenceLocation,
        condition: sample.condition,
        beaconId: sample.beaconId,
      );
      groups.putIfAbsent(key, () => []).add(sample.rssiDbm);
    }
    return Map.unmodifiable(
      groups.map((key, values) => MapEntry(key, statistics(values))),
    );
  }

  /// Calibration and trial must be separate runs. No training on the trial.
  List<RssiFilterComparison> compare({
    required List<RssiMeasurement> calibration,
    required List<RssiMeasurement> trial,
    int minimumSharedBeacons = 2,
  }) {
    if (calibration.isEmpty || trial.isEmpty || minimumSharedBeacons < 1) {
      throw const FormatException(
        'Faltan lecturas o el mínimo de balizas es inválido.',
      );
    }
    final first = trial.first;
    if (trial.any(
      (sample) =>
          sample.sourceId != first.sourceId ||
          sample.runId != first.runId ||
          sample.referenceLocation != first.referenceLocation ||
          sample.condition != first.condition,
    )) {
      throw const FormatException(
        'La prueba debe contener una sola sesión y referencia.',
      );
    }
    if (calibration.any(
      (sample) =>
          sample.sourceId == first.sourceId && sample.runId == first.runId,
    )) {
      throw const FormatException(
        'La calibración no puede incluir la sesión de prueba.',
      );
    }
    final byLocation = <String, Map<BeaconIdentifier, List<int>>>{};
    for (final sample in calibration) {
      if (sample.condition != first.condition ||
          sample.sourceId != first.sourceId) {
        continue;
      }
      byLocation
          .putIfAbsent(sample.referenceLocation, () => {})
          .putIfAbsent(sample.beaconId, () => [])
          .add(sample.rssiDbm);
    }
    if (byLocation.isEmpty) {
      throw const FormatException(
        'No hay calibración para esta fuente y condición.',
      );
    }
    final trialByBeacon = <BeaconIdentifier, List<int>>{};
    for (final sample in trial) {
      trialByBeacon.putIfAbsent(sample.beaconId, () => []).add(sample.rssiDbm);
    }
    return RssiFilter.values
        .map((filter) {
          final observed = trialByBeacon.map(
            (id, values) => MapEntry(id, statistics(values).valueFor(filter)),
          );
          final estimates = <RssiLocationEstimate>[];
          for (final entry in byLocation.entries) {
            final shared = entry.value.keys
                .where(observed.containsKey)
                .toList();
            if (shared.length < minimumSharedBeacons) continue;
            final error =
                shared
                    .map(
                      (id) =>
                          (observed[id]! -
                                  statistics(entry.value[id]!).valueFor(filter))
                              .abs(),
                    )
                    .reduce((a, b) => a + b) /
                shared.length;
            estimates.add(
              RssiLocationEstimate(
                referenceLocation: entry.key,
                meanAbsoluteErrorDb: error,
                sharedBeaconCount: shared.length,
              ),
            );
          }
          estimates.sort((a, b) {
            final coverage = b.sharedBeaconCount.compareTo(a.sharedBeaconCount);
            return coverage != 0
                ? coverage
                : a.meanAbsoluteErrorDb.compareTo(b.meanAbsoluteErrorDb);
          });
          return RssiFilterComparison(
            filter: filter,
            rankedLocations: List.unmodifiable(estimates),
            actualLocation: first.referenceLocation,
          );
        })
        .toList(growable: false);
  }

  double _mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  double _median(List<double> sorted) {
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
