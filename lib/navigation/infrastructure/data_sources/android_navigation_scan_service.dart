import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../application/navigation_scan_service.dart';
import '../../domain/entities/beacon_identifier.dart';
import '../../domain/entities/ble_scan_event.dart';
import '../../domain/entities/indoor_navigation.dart';
import '../permissions/ble_permission_service.dart';
import 'ble_platform_data_provider.dart';

class AndroidNavigationScanService implements NavigationScanService {
  AndroidNavigationScanService(this.provider, this.permissions);
  final BlePlatformDataProvider provider;
  final BlePermissionService permissions;
  bool _owned = false;
  @override
  Stream<BleScanEvent> get events =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? const Stream.empty()
      : provider.events.map((e) => e.toDomain());
  @override
  Future<void> start(Set<BeaconIdentifier> inventory) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const NavigationFailure('La localización BLE requiere Android.');
    }
    if (!await permissions.requestScanPermissions()) {
      throw const NavigationFailure(
        'Autoriza Bluetooth y ubicación precisa para continuar.',
      );
    }
    await const MethodChannel('com.uitopic.rumbo/ble_scan').invokeMethod<void>(
      'startNavigation',
      {'beaconIdentities': inventory.map((id) => id.toString()).toList()},
    );
    _owned = true;
  }

  @override
  Future<void> stop() async {
    if (_owned) {
      await provider.stop();
      _owned = false;
    }
  }
}
