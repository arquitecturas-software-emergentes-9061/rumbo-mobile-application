import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/domain/services/destination_search_service.dart';

const _directory = [
  Destination(
    id: 'spec-cardiologia',
    name: 'Cardiología — Consultorio 204',
    kind: DestinationKind.specialty,
    floor: 2,
    zone: 'Zona B',
    room: '204',
  ),
  Destination(
    id: 'doc-ana-torres',
    name: 'Dra. Ana Torres — Cardiología',
    kind: DestinationKind.doctor,
    floor: 2,
    room: '204',
    specialist: 'Dra. Ana Torres',
  ),
  Destination(
    id: 'lab',
    name: 'Laboratorio',
    kind: DestinationKind.laboratory,
    floor: 1,
    keywords: ['análisis'],
  ),
];

void main() {
  const service = DestinationSearchService();

  test('encuentra por texto ignorando tildes y mayúsculas', () {
    final result = service.search(_directory, 'CARDIO');
    expect(result.map((d) => d.id), ['spec-cardiologia', 'doc-ana-torres']);
    expect(service.search(_directory, 'analisis').single.id, 'lab');
  });

  test('encuentra por número de consultorio', () {
    expect(service.search(_directory, '204'), hasLength(2));
  });

  test('exige todas las palabras de la consulta', () {
    expect(service.search(_directory, 'cardio torres').single.id, 'doc-ana-torres');
    expect(service.search(_directory, 'cardio laboratorio'), isEmpty);
  });

  test('filtra por categoría y una consulta vacía lista la categoría', () {
    expect(
      service.search(_directory, 'cardio', kind: DestinationKind.doctor).single.id,
      'doc-ana-torres',
    );
    expect(service.search(_directory, '', kind: DestinationKind.laboratory), hasLength(1));
  });

  test('sugiere un destino cuando hay un error de escritura', () {
    expect(service.search(_directory, 'cardiolgía'), isEmpty);
    expect(service.suggest(_directory, 'cardiolgía')?.id, 'spec-cardiologia');
  });

  test('no sugiere nada si la consulta no se parece a un destino', () {
    expect(service.suggest(_directory, 'xyzxyz'), isNull);
    expect(service.suggest(_directory, 'ca'), isNull);
  });
}
