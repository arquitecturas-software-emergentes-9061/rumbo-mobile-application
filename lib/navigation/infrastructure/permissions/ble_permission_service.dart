abstract class BlePermissionService {
  Future<bool> requestScanPermissions();
  Future<void> openSettings();
}
