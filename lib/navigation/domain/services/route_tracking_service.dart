import '../entities/indoor_navigation.dart';

class RouteProgress {
  const RouteProgress(
    this.nodeIndex,
    this.segmentIndex,
    this.fraction,
    this.floorChanged,
  );
  final int nodeIndex, segmentIndex;
  final double fraction;
  final bool floorChanged;
}

/// Uses recognized published nodes, avoiding uncalibrated metric tolerances.
class RouteTrackingService {
  RouteProgress? match(
    PublishedRoute route,
    IndoorPosition position, {
    RouteProgress? previous,
  }) {
    if (!position.reliable ||
        position.siteId != route.siteId ||
        position.modelVersionId != route.modelVersionId) {
      return null;
    }
    final i = route.nodes.indexWhere(
      (n) =>
          n.id == position.nodeId &&
          n.floorId == position.floorId &&
          n.planVersionId == position.planVersionId,
    );
    if (i < 0) return null;
    return RouteProgress(
      i,
      i < route.nodes.length - 1 ? i : (i - 1).clamp(0, i),
      route.nodes.length == 1 ? 1 : i / (route.nodes.length - 1),
      previous != null &&
          route.nodes[previous.nodeIndex].floorId != position.floorId,
    );
  }
}

class DeviationService {
  DeviationService({
    this.persistence = const Duration(seconds: 8),
    this.minimumFixes = 3,
  });
  final Duration persistence;
  final int minimumFixes;
  DateTime? _since;
  int _fixes = 0;
  DateTime? _lastFix;
  bool update(PublishedRoute route, IndoorPosition position) {
    if (!position.reliable ||
        position.siteId != route.siteId ||
        position.modelVersionId != route.modelVersionId) {
      reset();
      return false;
    }
    if (_lastFix != null && !position.observedAt.isAfter(_lastFix!)) {
      return false;
    }
    _lastFix = position.observedAt;
    if (route.nodes.any(
      (n) =>
          n.id == position.nodeId &&
          n.floorId == position.floorId &&
          n.planVersionId == position.planVersionId,
    )) {
      reset();
      return false;
    }
    _since ??= position.observedAt;
    _fixes++;
    return _fixes >= minimumFixes &&
        position.observedAt.difference(_since!) >= persistence;
  }

  void reset() {
    _since = null;
    _fixes = 0;
    _lastFix = null;
  }
}
