import 'package:permission_handler/permission_handler.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ble_platform_data_provider.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/ble_permission_service.dart';

class AndroidBlePermissionService implements BlePermissionService {
  const AndroidBlePermissionService({required this.blePlatformDataProvider});

  final BlePlatformDataProvider blePlatformDataProvider;

  @override
  Future<bool> requestScanPermissions() async {
    final sdk = await blePlatformDataProvider.androidSdkVersion();
    if (sdk == 0) return false;

    // RSSI is used for indoor positioning, so precise location is required.
    final location = await Permission.locationWhenInUse.request();
    if (!location.isGranted) return false;

    if (sdk >= 31) {
      final scan = await Permission.bluetoothScan.request();
      if (!scan.isGranted) return false;
      final connect = await Permission.bluetoothConnect.request();
      if (!connect.isGranted) return false;
    }

    // Notification consent is useful but does not gate the foreground scan.
    if (sdk >= 33) await Permission.notification.request();
    return true;
  }

  @override
  Future<bool> requestAdvertisePermission() async {
    final sdk = await blePlatformDataProvider.androidSdkVersion();
    if (sdk < 31) return false;
    final advertise = await Permission.bluetoothAdvertise.request();
    return advertise.isGranted;
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
