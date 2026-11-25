/// A prototype heading only. It is not a BLE position or a backend route.
class ArDemoInstruction {
  ArDemoInstruction({required this.headingDegrees}) {
    if (!headingDegrees.isFinite || headingDegrees < 0 || headingDegrees >= 360) {
      throw const FormatException('La dirección de prueba debe estar entre 0° y 359°.');
    }
  }

  final double headingDegrees;
}
