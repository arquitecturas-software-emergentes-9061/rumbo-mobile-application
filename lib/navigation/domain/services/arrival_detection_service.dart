import '../entities/indoor_navigation.dart';

/// Distance to the destination measured by the AR session (visual-inertial
/// odometry, VIO). [tracking] is false while the AR reference is lost.
class VioObservation {
  const VioObservation({
    required this.nodeId,
    required this.metersToNode,
    required this.observedAt,
    this.tracking = true,
  });

  final String nodeId;
  final double metersToNode;
  final DateTime observedAt;
  final bool tracking;
}

/// What the detector concluded after the last observation.
enum ArrivalStatus {
  /// Not at the destination, or not sure yet.
  enRoute,

  /// The visitor is at the destination: ask for confirmation once.
  arrived,
}

/// Which evidence confirmed the arrival, for the session record.
enum ArrivalEvidence { ble, vio, bleAndVio }

class ArrivalDecision {
  const ArrivalDecision._(this.status, this.evidence);

  static const enRoute = ArrivalDecision._(ArrivalStatus.enRoute, null);

  const ArrivalDecision.arrived(ArrivalEvidence evidence)
    : this._(ArrivalStatus.arrived, evidence);

  final ArrivalStatus status;
  final ArrivalEvidence? evidence;

  bool get arrived => status == ArrivalStatus.arrived;
}

/// Arrival rule of PR-343 and PR-344: BLE and VIO must agree, or one of them
/// must hold steadily, before the app says the visitor arrived.
///
/// - **BLE alone:** [minimumBleFixes] reliable fixes in a row at the
///   destination node, spanning at least [bleDwell].
/// - **VIO alone:** the AR distance stays within [arrivalRadiusMeters] for at
///   least [vioDwell], while AR is tracking and the last reliable BLE fix is on
///   the destination floor.
/// - **Both:** one reliable BLE fix at the destination plus a VIO distance
///   within the radius, both fresher than [maximumAge], confirm at once.
///
/// False positives are filtered out: an unreliable fix, a fix of another
/// site, map version, floor or node, a lost AR reference or a VIO distance
/// outside the radius restart the count; observations older than the last
/// one are ignored. After [snooze] (the visitor said "not yet") nothing is
/// reported for that time, and once [ArrivalStatus.arrived] has been
/// reported it is not reported again until [reset].
class ArrivalDetectionService {
  ArrivalDetectionService({
    this.minimumBleFixes = 3,
    this.bleDwell = const Duration(seconds: 4),
    this.vioDwell = const Duration(seconds: 2),
    this.arrivalRadiusMeters = 1.5,
    this.maximumAge = const Duration(seconds: 3),
  });

  final int minimumBleFixes;
  final Duration bleDwell;
  final Duration vioDwell;
  final double arrivalRadiusMeters;
  final Duration maximumAge;

  RouteNode? _destination;
  String? _siteId;
  String? _modelVersionId;

  int _bleFixes = 0;
  DateTime? _bleSince;
  DateTime? _lastBle;
  DateTime? _lastBleAtDestination;
  bool _lastReliableFixOnDestinationFloor = false;

  DateTime? _vioSince;
  DateTime? _lastVio;
  DateTime? _lastVioInside;

  DateTime? _snoozedUntil;
  bool _reported = false;

  /// Starts watching the last node of [route].
  void watch(PublishedRoute route) {
    final destination = route.nodes.last;
    final changed =
        _destination?.id != destination.id ||
        _modelVersionId != route.modelVersionId;
    _destination = destination;
    _siteId = route.siteId;
    _modelVersionId = route.modelVersionId;
    if (changed) reset();
  }

  /// Forgets the evidence and allows a new report.
  void reset() {
    _clearBle();
    _clearVio();
    _lastBle = null;
    _lastVio = null;
    _lastReliableFixOnDestinationFloor = false;
    _snoozedUntil = null;
    _reported = false;
  }

  /// The visitor said they are not there yet: keep quiet for [duration] and
  /// require fresh evidence afterwards.
  void snooze(DateTime now, {Duration duration = const Duration(seconds: 20)}) {
    _clearBle();
    _clearVio();
    _reported = false;
    _snoozedUntil = now.add(duration);
  }

  ArrivalDecision onBle(IndoorPosition position) {
    final destination = _destination;
    if (destination == null) return ArrivalDecision.enRoute;
    if (_lastBle != null && !position.observedAt.isAfter(_lastBle!)) {
      return ArrivalDecision.enRoute;
    }
    _lastBle = position.observedAt;
    if (!position.reliable ||
        position.siteId != _siteId ||
        position.modelVersionId != _modelVersionId) {
      _clearBle();
      _lastReliableFixOnDestinationFloor = false;
      return ArrivalDecision.enRoute;
    }
    _lastReliableFixOnDestinationFloor =
        position.floorId == destination.floorId &&
        position.planVersionId == destination.planVersionId;
    final atDestination =
        _lastReliableFixOnDestinationFloor && position.nodeId == destination.id;
    if (!atDestination) {
      _clearBle();
      return ArrivalDecision.enRoute;
    }
    _bleSince ??= position.observedAt;
    _bleFixes++;
    _lastBleAtDestination = position.observedAt;
    return _decide(position.observedAt);
  }

  ArrivalDecision onVio(VioObservation observation) {
    final destination = _destination;
    if (destination == null) return ArrivalDecision.enRoute;
    if (_lastVio != null && !observation.observedAt.isAfter(_lastVio!)) {
      return ArrivalDecision.enRoute;
    }
    _lastVio = observation.observedAt;
    final inside =
        observation.tracking &&
        observation.nodeId == destination.id &&
        observation.metersToNode.isFinite &&
        observation.metersToNode >= 0 &&
        observation.metersToNode <= arrivalRadiusMeters;
    if (!inside) {
      _clearVio();
      return ArrivalDecision.enRoute;
    }
    _vioSince ??= observation.observedAt;
    _lastVioInside = observation.observedAt;
    return _decide(observation.observedAt);
  }

  ArrivalDecision _decide(DateTime now) {
    if (_reported) return ArrivalDecision.enRoute;
    if (_snoozedUntil != null && now.isBefore(_snoozedUntil!)) {
      return ArrivalDecision.enRoute;
    }
    final bleSteady =
        _bleSince != null &&
        _bleFixes >= minimumBleFixes &&
        now.difference(_bleSince!) >= bleDwell;
    final bleFresh =
        _lastBleAtDestination != null &&
        now.difference(_lastBleAtDestination!) <= maximumAge;
    final vioFresh =
        _lastVioInside != null && now.difference(_lastVioInside!) <= maximumAge;
    final vioSteady =
        vioFresh &&
        _vioSince != null &&
        now.difference(_vioSince!) >= vioDwell &&
        _lastReliableFixOnDestinationFloor;

    final ArrivalEvidence? evidence;
    if (bleFresh && vioFresh) {
      evidence = ArrivalEvidence.bleAndVio;
    } else if (bleSteady) {
      evidence = ArrivalEvidence.ble;
    } else if (vioSteady) {
      evidence = ArrivalEvidence.vio;
    } else {
      evidence = null;
    }
    if (evidence == null) return ArrivalDecision.enRoute;
    _reported = true;
    return ArrivalDecision.arrived(evidence);
  }

  void _clearBle() {
    _bleFixes = 0;
    _bleSince = null;
    _lastBleAtDestination = null;
  }

  void _clearVio() {
    _vioSince = null;
    _lastVioInside = null;
  }
}
