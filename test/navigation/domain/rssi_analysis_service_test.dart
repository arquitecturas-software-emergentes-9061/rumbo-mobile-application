import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_analysis.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_measurement.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/reference_point.dart';
import 'package:rumbo_mobile_application/navigation/domain/services/rssi_analysis_service.dart';

void main() {
  final firstBeacon = BeaconIdentifier(
    uuid: '11111111-2222-3333-4444-555555555555',
    major: 1,
    minor: 1,
  );
  final secondBeacon = BeaconIdentifier(
    uuid: '11111111-2222-3333-4444-555555555555',
    major: 1,
    minor: 2,
  );
  const analyzer = RssiAnalysisService();

  RssiMeasurement sample(
    BeaconIdentifier beacon,
    int rssi, {
    required String run,
    required String location,
    String source = 'device-1',
  }) => RssiMeasurement(
    beaconId: beacon,
    rssiDbm: rssi,
    observedAt: DateTime.utc(2026, 1, 1),
    sourceId: source,
    runId: run,
    referenceLocation: location,
    condition: 'quieta',
  );

  test('robust mean excludes an injected RSSI outlier', () {
    final result = analyzer.statistics([-60, -61, -59, -100]);
    expect(result.meanDbm, -70);
    expect(result.medianDbm, -60.5);
    expect(result.robustMeanDbm, -60);
    expect(result.outlierCount, 1);
    expect(result.medianAbsoluteDeviationDb, 1);
    expect(result.standardDeviationDb, greaterThan(0));
  });

  test('groups stability by source, run, location, condition and beacon', () {
    final summary = analyzer.summarize([
      sample(firstBeacon, -60, run: 'r1', location: 'A'),
      sample(firstBeacon, -62, run: 'r1', location: 'A'),
      sample(firstBeacon, -80, run: 'r2', location: 'A', source: 'device-2'),
    ]);
    expect(summary.length, 2);
    expect(summary.values.map((value) => value.count), containsAll([2, 1]));
  });

  test('compares fingerprint methods on a separate trial run', () {
    final calibration = [
      sample(firstBeacon, -60, run: 'cal', location: 'A'),
      sample(secondBeacon, -80, run: 'cal', location: 'A'),
      sample(firstBeacon, -80, run: 'cal', location: 'B'),
      sample(secondBeacon, -60, run: 'cal', location: 'B'),
    ];
    final trial = [
      sample(firstBeacon, -61, run: 'trial', location: 'A'),
      sample(secondBeacon, -79, run: 'trial', location: 'A'),
    ];
    final results = analyzer.compare(calibration: calibration, trial: trial);
    expect(results.map((result) => result.filter), RssiFilter.values);
    for (final result in results) {
      expect(result.estimatedLocation, 'A');
      expect(result.matchesReference, isTrue);
      expect(result.rankedLocations.first.meanAbsoluteErrorDb, 1);
      expect(result.rankedLocations.first.sharedBeaconCount, 2);
      expect(result.referencePointSeparationMeters(const {}), isNull);
      expect(
        result.referencePointSeparationMeters({
          'A': ReferencePoint(floorId: 'floor-1', xMeters: 0, yMeters: 0),
          'B': ReferencePoint(floorId: 'floor-1', xMeters: 3, yMeters: 4),
        }),
        0,
      );
    }
  });

  test('rejects calibration leakage and ambiguous single-beacon evidence', () {
    final a = sample(firstBeacon, -60, run: 'same', location: 'A');
    expect(
      () => analyzer.compare(calibration: [a], trial: [a]),
      throwsFormatException,
    );
    final comparisons = analyzer.compare(
      calibration: [
        sample(firstBeacon, -60, run: 'cal', location: 'A'),
        sample(firstBeacon, -80, run: 'cal', location: 'B'),
      ],
      trial: [sample(firstBeacon, -60, run: 'trial', location: 'A')],
    );
    expect(
      comparisons.every((result) => result.estimatedLocation == null),
      isTrue,
    );
  });

  test('requires calibration from the same source as the trial', () {
    expect(
      () => analyzer.compare(
        calibration: [sample(firstBeacon, -60, run: 'cal', location: 'A')],
        trial: [
          sample(
            firstBeacon,
            -60,
            run: 'trial',
            location: 'A',
            source: 'iphone-device',
          ),
        ],
      ),
      throwsFormatException,
    );
  });
}
