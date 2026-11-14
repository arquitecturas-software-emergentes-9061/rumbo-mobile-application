import 'package:rumbo_mobile_application/navigation/domain/entities/ar_demo_instruction.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ar_platform_bridge.dart';

class ArPrototypeFacade {
  const ArPrototypeFacade(this.bridge);

  final ArPlatformBridge bridge;

  Stream<Map<Object?, Object?>> get events => bridge.events;

  Future<void> open(ArDemoInstruction instruction) =>
      bridge.openDemo(instruction.headingDegrees);

  Future<bool> exportTrackingCsv() => bridge.exportTrackingCsv();
}
