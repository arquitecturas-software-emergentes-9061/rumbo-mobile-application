import 'package:rumbo_mobile_application/navigation/domain/entities/reference_point.dart';

enum RssiFilter { mean, median, robustMean }

class RssiStatistics {
  const RssiStatistics({
    required this.count,
    required this.meanDbm,
    required this.medianDbm,
    required this.robustMeanDbm,
    required this.standardDeviationDb,
    required this.medianAbsoluteDeviationDb,
    required this.outlierCount,
  });

  final int count;
  final double meanDbm;
  final double medianDbm;
  final double robustMeanDbm;
  final double standardDeviationDb;
  final double medianAbsoluteDeviationDb;
  final int outlierCount;

  double valueFor(RssiFilter filter) => switch (filter) {
    RssiFilter.mean => meanDbm,
    RssiFilter.median => medianDbm,
    RssiFilter.robustMean => robustMeanDbm,
  };
}

class RssiLocationEstimate {
  const RssiLocationEstimate({
    required this.referenceLocation,
    required this.meanAbsoluteErrorDb,
    required this.sharedBeaconCount,
  });

  final String referenceLocation;

  /// Signal mismatch, not physical distance or calibrated confidence.
  final double meanAbsoluteErrorDb;
  final int sharedBeaconCount;
}

class RssiFilterComparison {
  const RssiFilterComparison({
    required this.filter,
    required this.rankedLocations,
    required this.actualLocation,
  });

  final RssiFilter filter;
  final List<RssiLocationEstimate> rankedLocations;
  final String actualLocation;

  /// Null means there was insufficient information or an exact tie.
  String? get estimatedLocation {
    if (rankedLocations.length < 2 ||
        rankedLocations[0].sharedBeaconCount !=
            rankedLocations[1].sharedBeaconCount ||
        rankedLocations[0].meanAbsoluteErrorDb ==
            rankedLocations[1].meanAbsoluteErrorDb) {
      return null;
    }
    return rankedLocations.first.referenceLocation;
  }

  bool? get matchesReference =>
      estimatedLocation == null ? null : estimatedLocation == actualLocation;

  /// Separation between surveyed reference points, not phone-position error.
  double? referencePointSeparationMeters(
    Map<String, ReferencePoint> referencePoints,
  ) {
    final estimated = estimatedLocation;
    if (estimated == null) return null;
    final actualPoint = referencePoints[actualLocation];
    final estimatedPoint = referencePoints[estimated];
    if (actualPoint == null || estimatedPoint == null) return null;
    return actualPoint.distanceMetersTo(estimatedPoint);
  }
}
