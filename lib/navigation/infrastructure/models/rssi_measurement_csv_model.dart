import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/rssi_measurement.dart';

/// Platform-neutral interchange format for normalized RSSI measurements.
class RssiMeasurementCsvModel {
  const RssiMeasurementCsvModel();

  static const header =
      'timestamp_utc,beacon_uuid,major,minor,rssi_dbm,reference_location,condition,source_id,run_id';

  String encode(Iterable<RssiMeasurement> measurements) {
    final rows = [header];
    for (final sample in measurements) {
      rows.add(
        [
          sample.observedAt.toUtc().toIso8601String(),
          sample.beaconId.uuid,
          sample.beaconId.major.toString(),
          sample.beaconId.minor.toString(),
          sample.rssiDbm.toString(),
          sample.referenceLocation,
          sample.condition,
          sample.sourceId,
          sample.runId,
        ].map(_quote).join(','),
      );
    }
    return '${rows.join('\n')}\n';
  }

  List<RssiMeasurement> decode(String csv) {
    return records(csv, header.split(','))
        .map((row) {
          return RssiMeasurement(
            beaconId: BeaconIdentifier(
              uuid: row['beacon_uuid']!,
              major: int.parse(row['major']!),
              minor: int.parse(row['minor']!),
            ),
            rssiDbm: int.parse(row['rssi_dbm']!),
            observedAt: DateTime.parse(row['timestamp_utc']!).toUtc(),
            referenceLocation: row['reference_location']!,
            condition: row['condition']!,
            sourceId: row['source_id']!,
            runId: row['run_id']!,
          );
        })
        .toList(growable: false);
  }

  String _quote(String value) => '"${value.replaceAll('"', '""')}"';

  List<Map<String, String>> records(String csv, List<String> expectedColumns) {
    final rows = _parseCsv(csv);
    if (rows.isEmpty || !_sameColumns(rows.first, expectedColumns)) {
      throw const FormatException('Cabecera CSV incompatible.');
    }
    return rows
        .skip(1)
        .map((cells) {
          if (cells.length != expectedColumns.length) {
            throw const FormatException('Fila CSV incompleta.');
          }
          return Map.fromIterables(expectedColumns, cells);
        })
        .toList(growable: false);
  }

  bool _sameColumns(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    var atFieldStart = true;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (quoted) {
        if (char == '"' && i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else if (char == '"') {
          quoted = false;
        } else {
          cell.write(char);
        }
      } else if (char == '"' && atFieldStart) {
        quoted = true;
        atFieldStart = false;
      } else if (char == ',') {
        row.add(cell.toString());
        cell = StringBuffer();
        atFieldStart = true;
      } else if (char == '\n' || char == '\r') {
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell = StringBuffer();
        atFieldStart = true;
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      } else {
        cell.write(char);
        atFieldStart = false;
      }
    }
    if (quoted) throw const FormatException('CSV con comillas sin cerrar.');
    if (row.isNotEmpty || cell.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }
}
