import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/application/destination_search_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/destination_repository.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_bloc.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_event.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_state.dart';

const _cardiology = Destination(
  id: 'spec-cardiologia',
  name: 'Cardiología — Consultorio 204',
  kind: DestinationKind.specialty,
  floor: 2,
);
const _doctor = Destination(
  id: 'doc-ana',
  name: 'Dra. Ana Torres — Cardiología',
  kind: DestinationKind.doctor,
  floor: 2,
);
const _noRoute = Destination(
  id: 'sin-ruta',
  name: 'Quirófano',
  kind: DestinationKind.service,
  floor: 3,
  isNavigable: false,
);

class _Repository implements DestinationRepository {
  _Repository({this.fail = false});
  final bool fail;

  @override
  Future<List<Destination>> fetchDirectory() async {
    if (fail) throw Exception('sin red');
    return const [_cardiology, _doctor, _noRoute];
  }
}

Future<DestinationSearchBloc> _loadedBloc() async {
  final bloc = DestinationSearchBloc(
    facade: DestinationSearchFacadeService(repository: _Repository()),
  )..add(const DirectoryRequested());
  await bloc.stream.firstWhere((s) => s.status == DirectoryStatus.ready);
  return bloc;
}

void main() {
  test('carga el directorio y queda listo', () async {
    final bloc = await _loadedBloc();
    expect(bloc.state.status, DirectoryStatus.ready);
    expect(bloc.state.isSearching, isFalse);
    await bloc.close();
  });

  test('un error al cargar deja el estado en failure', () async {
    final bloc = DestinationSearchBloc(
      facade: DestinationSearchFacadeService(repository: _Repository(fail: true)),
    )..add(const DirectoryRequested());
    final state = await bloc.stream.firstWhere((s) => s.status != DirectoryStatus.loading);
    expect(state.status, DirectoryStatus.failure);
    await bloc.close();
  });

  test('buscar "cardio" devuelve dos coincidencias con conteo por categoría', () async {
    final bloc = await _loadedBloc();
    bloc.add(const QueryChanged('cardio'));
    final state = await bloc.stream.firstWhere((s) => s.query == 'cardio');
    expect(state.matches, hasLength(2));
    expect(state.totalCount, 2);
    expect(state.kindCounts[DestinationKind.specialty], 1);
    expect(state.kindCounts[DestinationKind.doctor], 1);
    await bloc.close();
  });

  test('el filtro de categoría reduce resultados sin perder los conteos', () async {
    final bloc = await _loadedBloc();
    bloc
      ..add(const QueryChanged('cardio'))
      ..add(const CategoryToggled(DestinationKind.doctor));
    final state = await bloc.stream.firstWhere((s) => s.kind == DestinationKind.doctor);
    expect(state.matches.single.id, 'doc-ana');
    expect(state.totalCount, 2);
    await bloc.close();
  });

  test('sin coincidencias propone un destino parecido', () async {
    final bloc = await _loadedBloc();
    bloc.add(const QueryChanged('cardiolgía'));
    final state = await bloc.stream.firstWhere((s) => s.query == 'cardiolgía');
    expect(state.hasNoResults, isTrue);
    expect(state.suggestion?.id, 'spec-cardiologia');
    await bloc.close();
  });

  test('seleccionar un destino válido lo expone y lo agrega a recientes', () async {
    final bloc = await _loadedBloc();
    bloc.add(const DestinationSelected(_cardiology));
    final state = await bloc.stream.firstWhere((s) => s.selection != null);
    expect(state.selection?.id, 'spec-cardiologia');
    expect(state.recents.single.id, 'spec-cardiologia');
    await bloc.close();
  });

  test('seleccionar un destino sin ruta informa el error y no navega', () async {
    final bloc = await _loadedBloc();
    bloc.add(const DestinationSelected(_noRoute));
    final state = await bloc.stream.firstWhere((s) => s.selectionError != null);
    expect(state.selection, isNull);
    expect(state.recents, isEmpty);
    await bloc.close();
  });
}
