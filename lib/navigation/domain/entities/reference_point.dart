import 'dart:math' as math;

/// Coordinates must use the same calibrated floor model and meter scale.
class ReferencePoint {
  ReferencePoint({
    required String floorId,
    required this.xMeters,
    required this.yMeters,
  }) : floorId = floorId.trim() {
    if (this.floorId.isEmpty || !xMeters.isFinite || !yMeters.isFinite) {
      throw const FormatException('Punto de referencia inválido.');
    }
  }

  final String floorId;
  final double xMeters;
  final double yMeters;

  double? distanceMetersTo(ReferencePoint other) {
    if (floorId != other.floorId) return null;
    return math.sqrt(
      math.pow(xMeters - other.xMeters, 2) +
          math.pow(yMeters - other.yMeters, 2),
    );
  }
}
