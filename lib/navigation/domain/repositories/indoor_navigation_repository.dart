import '../entities/beacon_identifier.dart';
import '../entities/indoor_navigation.dart';
import '../services/rssi_window_service.dart';

abstract class IndoorNavigationRepository {
  Future<Set<BeaconIdentifier>> beacons(String siteId);
  Future<IndoorPosition?> resolve(String siteId, List<FilteredBeacon> signals);
  Future<PublishedRoute> route(NavigationTarget target, IndoorPosition origin);
}
