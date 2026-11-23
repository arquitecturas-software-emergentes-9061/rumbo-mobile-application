import '../domain/entities/beacon_identifier.dart';
import '../domain/entities/ble_scan_event.dart';

abstract class NavigationScanService {
  Stream<BleScanEvent> get events;
  Future<void> start(Set<BeaconIdentifier> inventory);
  Future<void> stop();
}
