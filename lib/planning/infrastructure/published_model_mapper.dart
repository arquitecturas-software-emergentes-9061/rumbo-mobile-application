import '../domain/published_indoor_model.dart';

class PublishedModelMapper {
  const PublishedModelMapper();

  PublishedIndoorModel decode(Map<String, dynamic> data, String requestedSite) {
    if (data['status'] != 'PUBLISHED' || data['siteId'] != requestedSite) {
      throw const FormatException(
        'La respuesta no corresponde al mapa oficial solicitado.',
      );
    }
    final version = text(data, 'modelVersionId');
    final labels = {
      for (final row in rows(data, 'floors'))
        text(row, 'id'): text(row, 'name'),
    };
    final plans = rows(data, 'plans');
    return PublishedIndoorModel(
      siteId: text(data, 'siteId'),
      mapId: text(data, 'mapId'),
      versionId: version,
      plans: [
        for (var i = 0; i < plans.length; i++)
          PublishedPlan(
            floorId: text(plans[i], 'floorId'),
            planVersionId: text(plans[i], 'planVersionId'),
            name: labels[text(plans[i], 'floorId')] ?? 'Plano ${i + 1}',
            widthUnits: number(plans[i], 'widthUnits'),
            heightUnits: number(plans[i], 'heightUnits'),
            metersPerUnit: number(plans[i], 'metersPerUnit'),
          ),
      ],
      nodes: rows(data, 'nodes')
          .map(
            (row) => PublishedNode(
              id: text(row, 'id'),
              floorId: text(row, 'floorId'),
              planVersionId: text(row, 'planVersionId'),
              x: number(row, 'x'),
              y: number(row, 'y'),
              type: text(row, 'type'),
            ),
          )
          .toList(),
      connections: rows(data, 'connections')
          .map(
            (row) => PublishedConnection(
              id: text(row, 'id'),
              sourceNodeId: text(row, 'sourceNodeId'),
              targetNodeId: text(row, 'targetNodeId'),
              type: text(row, 'type'),
              distanceMeters: number(row, 'distanceMeters'),
              weight: number(row, 'weight'),
              verticalPenalty: number(row, 'verticalPenalty'),
              accessibility: text(row, 'accessibility'),
              bidirectional: boolean(row, 'bidirectional'),
            ),
          )
          .toList(),
      destinations: rows(data, 'destinations').map((row) {
        if (row['modelVersionId'] != version) {
          throw const FormatException('Destino de otra versión.');
        }
        return PublishedDestination(
          id: text(row, 'id'),
          nodeId: text(row, 'nodeId'),
          floorId: text(row, 'floorId'),
          name: text(row, 'name'),
          type: text(row, 'type'),
        );
      }).toList(),
      walls: rows(data, 'walls')
          .map(
            (row) => PublishedWall(
              id: text(row, 'id'),
              floorId: text(row, 'floorId'),
              planVersionId: text(row, 'planVersionId'),
              x1: number(row, 'x1'),
              y1: number(row, 'y1'),
              x2: number(row, 'x2'),
              y2: number(row, 'y2'),
            ),
          )
          .toList(),
      doors: rows(data, 'doors')
          .map(
            (row) => PublishedDoor(
              id: text(row, 'id'),
              wallId: text(row, 'wallId'),
              from: number(row, 'from'),
              to: number(row, 'to'),
            ),
          )
          .toList(),
    );
  }

  static List<Map<String, dynamic>> rows(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
      throw FormatException('Lista $key inválida.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  static String text(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo $key inválido.');
    }
    return value;
  }

  static double number(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('Campo $key inválido.');
    }
    return value.toDouble();
  }

  static bool boolean(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('Campo $key inválido.');
    return value;
  }
}
