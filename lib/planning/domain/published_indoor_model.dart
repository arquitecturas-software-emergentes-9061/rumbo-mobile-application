class PublishedSite {
  const PublishedSite({required this.id, required this.name});
  final String id;
  final String name;
}

class PublishedPlan {
  const PublishedPlan({
    required this.floorId,
    required this.planVersionId,
    required this.name,
    required this.widthUnits,
    required this.heightUnits,
    required this.metersPerUnit,
  });
  final String floorId, planVersionId, name;
  final double widthUnits, heightUnits, metersPerUnit;
}

class PublishedNode {
  const PublishedNode({
    required this.id,
    required this.floorId,
    required this.planVersionId,
    required this.x,
    required this.y,
    required this.type,
  });
  final String id, floorId, planVersionId, type;
  final double x, y;
}

class PublishedConnection {
  const PublishedConnection({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.type,
    required this.distanceMeters,
    required this.weight,
    required this.verticalPenalty,
    required this.accessibility,
    required this.bidirectional,
  });
  final String id, sourceNodeId, targetNodeId, type, accessibility;
  final double distanceMeters, weight, verticalPenalty;
  final bool bidirectional;
}

class PublishedDestination {
  const PublishedDestination({
    required this.id,
    required this.nodeId,
    required this.floorId,
    required this.name,
    required this.type,
  });
  final String id, nodeId, floorId, name, type;
}

class PublishedWall {
  const PublishedWall({
    required this.id,
    required this.floorId,
    required this.planVersionId,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  final String id, floorId, planVersionId;
  final double x1, y1, x2, y2;
}

class PublishedDoor {
  const PublishedDoor({
    required this.id,
    required this.wallId,
    required this.from,
    required this.to,
  });
  final String id, wallId;
  final double from, to;
}

/// An immutable, internally consistent official graph; no stale fallback is exposed.
class PublishedIndoorModel {
  PublishedIndoorModel({
    required this.siteId,
    required this.mapId,
    required this.versionId,
    required List<PublishedPlan> plans,
    required List<PublishedNode> nodes,
    required List<PublishedConnection> connections,
    required List<PublishedDestination> destinations,
    required List<PublishedWall> walls,
    required List<PublishedDoor> doors,
  }) : plans = List.unmodifiable(plans),
       nodes = List.unmodifiable(nodes),
       connections = List.unmodifiable(connections),
       destinations = List.unmodifiable(destinations),
       walls = List.unmodifiable(walls),
       doors = List.unmodifiable(doors) {
    if ([siteId, mapId, versionId].any((id) => id.trim().isEmpty) ||
        plans.isEmpty ||
        nodes.isEmpty) {
      throw const FormatException('El modelo publicado está incompleto.');
    }
    _unique(plans.map((plan) => plan.planVersionId));
    _unique(plans.map((plan) => plan.floorId));
    _unique(nodes.map((node) => node.id));
    _unique(connections.map((link) => link.id));
    _unique(destinations.map((destination) => destination.id));
    _unique(walls.map((wall) => wall.id));
    _unique(doors.map((door) => door.id));
    final planById = {for (final plan in plans) plan.planVersionId: plan};
    final nodeById = {for (final node in nodes) node.id: node};
    for (final plan in plans) {
      if (plan.name.trim().isEmpty ||
          !_positive(plan.widthUnits) ||
          !_positive(plan.heightUnits) ||
          !_positive(plan.metersPerUnit)) {
        throw const FormatException('Plano sin escala o dimensiones válidas.');
      }
    }
    bool contains(String floor, String version, double x, double y) {
      final plan = planById[version];
      return plan != null &&
          plan.floorId == floor &&
          x.isFinite &&
          y.isFinite &&
          x >= 0 &&
          y >= 0 &&
          x <= plan.widthUnits &&
          y <= plan.heightUnits;
    }

    for (final node in nodes) {
      if (!contains(node.floorId, node.planVersionId, node.x, node.y) ||
          !{
            'ACCESS',
            'DESTINATION',
            'INTERSECTION',
            'VERTICAL_LINK',
            'REFERENCE',
          }.contains(node.type)) {
        throw const FormatException(
          'Nodo incompatible con el plano publicado.',
        );
      }
    }
    for (final link in connections) {
      final source = nodeById[link.sourceNodeId],
          target = nodeById[link.targetNodeId];
      if (source == null ||
          target == null ||
          source.id == target.id ||
          !_positive(link.distanceMeters) ||
          !_positive(link.weight) ||
          !link.verticalPenalty.isFinite ||
          link.verticalPenalty < 0 ||
          !{
            'CORRIDOR',
            'DOORWAY',
            'STAIRS',
            'RAMP',
            'ELEVATOR',
          }.contains(link.type) ||
          !{
            'UNKNOWN',
            'ACCESSIBLE',
            'INACCESSIBLE',
          }.contains(link.accessibility) ||
          (source.floorId != target.floorId &&
              !{'STAIRS', 'RAMP', 'ELEVATOR'}.contains(link.type))) {
        throw const FormatException(
          'Conexión incompatible con el modelo publicado.',
        );
      }
    }
    for (final destination in destinations) {
      final node = nodeById[destination.nodeId];
      if (node == null ||
          node.type != 'DESTINATION' ||
          node.floorId != destination.floorId ||
          destination.name.trim().isEmpty) {
        throw const FormatException('Destino sin referencia válida.');
      }
    }
    final wallById = {for (final wall in walls) wall.id: wall};
    for (final wall in walls) {
      if (!contains(wall.floorId, wall.planVersionId, wall.x1, wall.y1) ||
          !contains(wall.floorId, wall.planVersionId, wall.x2, wall.y2)) {
        throw const FormatException(
          'Muro incompatible con el plano publicado.',
        );
      }
    }
    for (final door in doors) {
      if (!wallById.containsKey(door.wallId) ||
          !door.from.isFinite ||
          !door.to.isFinite ||
          door.from < 0 ||
          door.to > 1 ||
          door.to <= door.from) {
        throw const FormatException('Puerta sin muro o abertura válida.');
      }
    }
  }

  final String siteId, mapId, versionId;
  final List<PublishedPlan> plans;
  final List<PublishedNode> nodes;
  final List<PublishedConnection> connections;
  final List<PublishedDestination> destinations;
  final List<PublishedWall> walls;
  final List<PublishedDoor> doors;

  static bool _positive(double value) => value.isFinite && value > 0;
  static void _unique(Iterable<String> ids) {
    final values = ids.toList();
    if (values.any((id) => id.trim().isEmpty) ||
        values.toSet().length != values.length) {
      throw const FormatException(
        'Identificadores duplicados o vacíos en el modelo.',
      );
    }
  }
}
