import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/destination_model.dart';

void main() {
  test('convierte el JSON del directorio a una entidad', () {
    final destination = DestinationModel.fromJson({
      'id': 'spec-1',
      'name': 'Cardiología',
      'kind': 'specialty',
      'floor': 2,
      'zone': 'Zona B',
      'estimatedMinutes': 3,
      'keywords': ['corazon'],
    }).toEntity();

    expect(destination.kind, DestinationKind.specialty);
    expect(destination.locationLabel, 'Piso 2 · Zona B');
    expect(destination.keywords, ['corazon']);
    expect(destination.isValid, isTrue);
  });

  test('una categoría desconocida cae en servicios y navigable es true por defecto', () {
    final destination = DestinationModel.fromJson({
      'id': 'x',
      'name': 'Capilla',
      'kind': 'CHAPEL',
      'floor': 1,
    }).toEntity();
    expect(destination.kind, DestinationKind.service);
    expect(destination.isNavigable, isTrue);
  });

  test('un destino no navegable no es válido para guiar', () {
    final destination = DestinationModel.fromJson({
      'id': 'x',
      'name': 'Quirófano',
      'kind': 'SERVICE',
      'floor': 3,
      'navigable': false,
    }).toEntity();
    expect(destination.isValid, isFalse);
  });
}
