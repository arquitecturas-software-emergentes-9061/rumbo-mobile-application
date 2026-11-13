import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/application/destination_search_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/destination_repository.dart';

class _FakeRepository implements DestinationRepository {
  _FakeRepository(this.items);
  final List<Destination> items;

  @override
  Future<List<Destination>> fetchDirectory() async => items;
}

Destination _destination(String id, {bool navigable = true}) => Destination(
      id: id,
      name: 'Destino $id',
      kind: DestinationKind.service,
      floor: 1,
      isNavigable: navigable,
    );

void main() {
  late DestinationSearchFacadeService facade;

  setUp(() async {
    facade = DestinationSearchFacadeService(
      repository: _FakeRepository([
        _destination('a'),
        _destination('b'),
        _destination('c'),
        _destination('sin-ruta', navigable: false),
      ]),
      maxRecents: 2,
    );
    await facade.loadDirectory();
  });

  test('selecciona un destino válido y lo guarda como reciente', () {
    final selected = facade.select(_destination('a'));
    expect(selected.id, 'a');
    expect(facade.recents.map((d) => d.id), ['a']);
  });

  test('rechaza un destino que no está en el directorio', () {
    expect(
      () => facade.select(_destination('fantasma')),
      throwsA(isA<InvalidDestinationException>()),
    );
    expect(facade.recents, isEmpty);
  });

  test('rechaza un destino sin ruta disponible', () {
    expect(
      () => facade.select(_destination('sin-ruta')),
      throwsA(isA<InvalidDestinationException>()),
    );
  });

  test('los recientes no se repiten y van del más nuevo al más viejo', () {
    facade
      ..select(_destination('a'))
      ..select(_destination('b'))
      ..select(_destination('a'));
    expect(facade.recents.map((d) => d.id), ['a', 'b']);
  });

  test('el tope de recientes descarta el más antiguo', () {
    facade
      ..select(_destination('a'))
      ..select(_destination('b'))
      ..select(_destination('c'));
    expect(facade.recents.map((d) => d.id), ['c', 'b']);
    facade.clearRecents();
    expect(facade.recents, isEmpty);
  });

  test('la sugerencia solo aparece cuando no hay coincidencias', () {
    expect(facade.search('destino').suggestion, isNull);
    expect(facade.search('zzzzzz').matches, isEmpty);
  });
}
