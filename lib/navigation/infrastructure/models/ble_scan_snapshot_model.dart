import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_snapshot.dart';

class BleScanSnapshotModel {
  const BleScanSnapshotModel(this.values);

  final Map<Object?, Object?> values;

  BleScanSnapshot toDomain() {
    return BleScanSnapshot(
      status: values['status'] as String? ?? 'idle',
      savedCount: values['savedCount'] as int? ?? 0,
      filePath: values['filePath'] as String? ?? '',
      message: values['message'] as String? ?? '',
    );
  }
}
