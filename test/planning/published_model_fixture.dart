import 'package:rumbo_mobile_application/planning/domain/published_indoor_model.dart';
import 'package:rumbo_mobile_application/planning/infrastructure/published_model_mapper.dart';

Map<String, dynamic> publishedJson({
  String site = 'site',
  String version = 'v1',
}) => {
  'siteId': site,
  'mapId': 'map',
  'modelVersionId': version,
  'status': 'PUBLISHED',
  'floors': [
    {'id': 'floor', 'number': 1, 'name': 'Primer piso'},
  ],
  'plans': [
    {
      'floorId': 'floor',
      'planVersionId': 'plan',
      'widthUnits': 100,
      'heightUnits': 80,
      'metersPerUnit': .5,
    },
  ],
  'nodes': [
    {
      'id': 'a',
      'floorId': 'floor',
      'planVersionId': 'plan',
      'x': 10,
      'y': 10,
      'type': 'ACCESS',
    },
    {
      'id': 'b',
      'floorId': 'floor',
      'planVersionId': 'plan',
      'x': 20,
      'y': 10,
      'type': 'DESTINATION',
    },
  ],
  'connections': [
    {
      'id': 'link',
      'sourceNodeId': 'a',
      'targetNodeId': 'b',
      'type': 'CORRIDOR',
      'distanceMeters': 5,
      'weight': 5,
      'verticalPenalty': 0,
      'accessibility': 'ACCESSIBLE',
      'bidirectional': true,
    },
  ],
  'destinations': [
    {
      'id': 'dest',
      'modelVersionId': version,
      'nodeId': 'b',
      'floorId': 'floor',
      'name': 'Recepción',
      'type': 'SERVICE',
    },
  ],
  'walls': [
    {
      'id': 'wall',
      'floorId': 'floor',
      'planVersionId': 'plan',
      'x1': 0,
      'y1': 0,
      'x2': 100,
      'y2': 0,
    },
  ],
  'doors': [
    {'id': 'door', 'wallId': 'wall', 'from': .1, 'to': .2},
  ],
};

PublishedIndoorModel publishedModel({
  String site = 'site',
  String version = 'v1',
}) => const PublishedModelMapper().decode(
  publishedJson(site: site, version: version),
  site,
);
