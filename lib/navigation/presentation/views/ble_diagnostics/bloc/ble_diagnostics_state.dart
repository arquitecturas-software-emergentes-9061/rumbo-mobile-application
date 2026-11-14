import 'package:rumbo_mobile_application/navigation/domain/entities/ble_observation.dart';

class BleDiagnosticsState {
  const BleDiagnosticsState({
    this.status = 'idle',
    this.message = '',
    this.busy = false,
    this.savedCount = 0,
    this.filePath = '',
    this.observations = const [],
  });

  final String status;
  final String message;
  final bool busy;
  final int savedCount;
  final String filePath;
  final List<BleObservation> observations;

  bool get isActive =>
      status == 'starting' ||
      status == 'discovering' ||
      status == 'scanning' ||
      status == 'paused' ||
      status == 'empty';

  BleDiagnosticsState copyWith({
    String? status,
    String? message,
    bool? busy,
    int? savedCount,
    String? filePath,
    List<BleObservation>? observations,
  }) {
    return BleDiagnosticsState(
      status: status ?? this.status,
      message: message ?? this.message,
      busy: busy ?? this.busy,
      savedCount: savedCount ?? this.savedCount,
      filePath: filePath ?? this.filePath,
      observations: observations ?? this.observations,
    );
  }
}
