abstract class BlePermissionService {
  Future<bool> requestScanPermissions();
  Future<bool> requestAdvertisePermission();
  Future<void> openSettings();
}
