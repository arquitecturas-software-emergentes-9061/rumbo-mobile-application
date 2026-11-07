import 'dart:io';

import 'package:rumbo_mobile_application/navigation/domain/services/rssi_analysis_service.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/android/android_phase1_rssi_csv_adapter.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/rssi_measurement_csv_model.dart';

/// Developer tool. It reports signal statistics, never calibrated accuracy.
void main(List<String> args) {
  const codec = RssiMeasurementCsvModel();
  if (args.length == 5 && args.first == 'normalize-android') {
    final input = File(args[1]);
    final output = File(args[2]);
    if (output.existsSync()) {
      stderr.writeln('El archivo de salida ya existe: ${output.path}');
      exitCode = 2;
      return;
    }
    try {
      final result = const AndroidPhase1RssiCsvAdapter().normalize(
        input.readAsStringSync(),
        sourceId: args[3],
        runId: args[4],
      );
      if (result.measurements.isEmpty) {
        stderr.writeln('No se resolvió ninguna identidad lógica de baliza.');
        exitCode = 2;
        return;
      }
      output.writeAsStringSync(codec.encode(result.measurements));
      stdout.writeln(
        'Normalizadas: ${result.measurements.length}; '
        'sin identidad verificable: ${result.unresolvedCount}.',
      );
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      exitCode = 2;
    }
    return;
  }

  if (args.length == 3 && args.first == 'compare') {
    try {
      final calibration = codec.decode(File(args[1]).readAsStringSync());
      final trial = codec.decode(File(args[2]).readAsStringSync());
      const analyzer = RssiAnalysisService();
      for (final entry in analyzer.summarize(trial).entries) {
        final key = entry.key;
        final statistics = entry.value;
        stdout.writeln(
          '${key.sourceId} | ${key.runId} | '
          '${key.referenceLocation} | ${key.condition} | ${key.beaconId}: '
          'n=${statistics.count}, desviación=${statistics.standardDeviationDb.toStringAsFixed(2)} dB, '
          'MAD=${statistics.medianAbsoluteDeviationDb.toStringAsFixed(2)} dB, '
          'atípicas=${statistics.outlierCount}',
        );
      }
      for (final comparison in analyzer.compare(
        calibration: calibration,
        trial: trial,
      )) {
        final best = comparison.rankedLocations.isEmpty
            ? 'sin suficientes balizas compartidas'
            : '${comparison.rankedLocations.first.referenceLocation} '
                  '(${comparison.rankedLocations.first.meanAbsoluteErrorDb.toStringAsFixed(2)} dB)';
        stdout.writeln(
          '${comparison.filter.name}: $best; '
          'estimación=${comparison.estimatedLocation ?? 'no concluyente'}; '
          'coincide=${comparison.matchesReference ?? 'indeterminado'}',
        );
      }
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      exitCode = 2;
    }
    return;
  }

  stderr.writeln(
    'Uso:\n'
    '  dart run tool/rssi_analysis.dart normalize-android <fase1.csv> <comun.csv> <source_id> <run_id>\n'
    '  dart run tool/rssi_analysis.dart compare <calibracion.csv> <prueba.csv>',
  );
  exitCode = 2;
}
