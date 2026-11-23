enum LocationQuality { searching, located, lowConfidence, signalLost, error }

enum GuidanceMode { map, ar, fallback }

class IndoorPosition {
  const IndoorPosition({
    required this.siteId,
    required this.floorId,
    required this.nodeId,
    required this.modelVersionId,
    required this.planVersionId,
    required this.x,
    required this.y,
    required this.observedAt,
    required this.reliable,
  });
  final String siteId, floorId, nodeId, modelVersionId, planVersionId;
  final double x, y;
  final DateTime observedAt;
  final bool reliable;
}

class RouteNode {
  const RouteNode(this.id, this.floorId, this.planVersionId, this.x, this.y);
  final String id, floorId, planVersionId;
  final double x, y;
}

class MobilityPreferences {
  const MobilityPreferences({
    this.accessibleOnly = false,
    this.avoidStairs = false,
    this.prioritizeElevators = false,
  });
  final bool accessibleOnly, avoidStairs, prioritizeElevators;
  Map<String, String> get query => {
    'accessibleOnly': '$accessibleOnly',
    'avoidStairs': '$avoidStairs',
    'prioritizeElevators': '$prioritizeElevators',
  };
}

class PublishedRoute {
  PublishedRoute({
    required this.siteId,
    required this.modelVersionId,
    required List<RouteNode> nodes,
  }) : nodes = List.unmodifiable(nodes) {
    if (nodes.isEmpty) throw const FormatException('Ruta sin nodos.');
  }
  final String siteId, modelVersionId;
  final List<RouteNode> nodes;
}

class NavigationTarget {
  const NavigationTarget({
    required this.siteId,
    required this.nodeId,
    required this.name,
    this.preferences = const MobilityPreferences(),
  });
  final String siteId, nodeId, name;
  final MobilityPreferences preferences;
}

class NavigationFailure implements Exception {
  const NavigationFailure(this.message, {this.code = 'ERROR'});
  final String message, code;
  @override
  String toString() => message;
}
