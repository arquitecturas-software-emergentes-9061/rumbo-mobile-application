/// Common capture metadata; platform adapters supply their own scan targets.
abstract class BleCaptureSession {
  BleCaptureSession({
    required String referenceLocation,
    required String condition,
  }) : referenceLocation = referenceLocation.trim(),
       condition = condition.trim() {
    if (this.referenceLocation.isEmpty || this.condition.isEmpty) {
      throw const FormatException('Indica la ubicación y condición de prueba.');
    }
  }

  final String referenceLocation;
  final String condition;
}
