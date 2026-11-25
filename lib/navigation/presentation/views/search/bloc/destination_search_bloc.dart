import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rumbo_mobile_application/navigation/application/destination_search_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_event.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_state.dart';

class DestinationSearchBloc
    extends Bloc<DestinationSearchEvent, DestinationSearchState> {
  DestinationSearchBloc({required DestinationSearchFacadeService facade})
      : _facade = facade,
        super(const DestinationSearchState()) {
    on<DirectoryRequested>(_onDirectoryRequested);
    on<QueryChanged>(_onQueryChanged);
    on<CategoryToggled>(_onCategoryToggled);
    on<DestinationSelected>(_onDestinationSelected);
    on<SelectionHandled>(
      (event, emit) =>
          emit(state.copyWith(selection: () => null, selectionError: () => null)),
    );
    on<HelpRequested>(_onHelpRequested);
    on<RecentsCleared>((event, emit) {
      _facade.clearRecents();
      emit(state.copyWith(recents: _facade.recents));
    });
  }

  final DestinationSearchFacadeService _facade;

  Future<void> _onDirectoryRequested(
    DirectoryRequested event,
    Emitter<DestinationSearchState> emit,
  ) async {
    emit(state.copyWith(status: DirectoryStatus.loading));
    try {
      await _facade.loadDirectory();
      emit(_refreshed(status: DirectoryStatus.ready));
    } catch (_) {
      emit(state.copyWith(status: DirectoryStatus.failure));
    }
  }

  void _onQueryChanged(
    QueryChanged event,
    Emitter<DestinationSearchState> emit,
  ) =>
      emit(_refreshed(query: event.query));

  void _onCategoryToggled(
    CategoryToggled event,
    Emitter<DestinationSearchState> emit,
  ) {
    final next = state.kind == event.kind ? null : event.kind;
    emit(_refreshed(kind: next, replaceKind: true));
  }

  void _onDestinationSelected(
    DestinationSelected event,
    Emitter<DestinationSearchState> emit,
  ) {
    try {
      final destination = _facade.select(event.destination);
      emit(state.copyWith(
        selection: () => destination,
        selectionError: () => null,
        recents: _facade.recents,
      ));
    } on InvalidDestinationException catch (error) {
      emit(state.copyWith(
        selection: () => null,
        selectionError: () => error.message,
      ));
    }
  }

  void _onHelpRequested(
    HelpRequested event,
    Emitter<DestinationSearchState> emit,
  ) {
    final desks = _facade.search('', kind: DestinationKind.service).matches;
    if (desks.isEmpty) {
      emit(state.copyWith(
        selectionError: () => 'No hay un módulo de informes disponible.',
      ));
      return;
    }
    add(DestinationSelected(desks.first));
  }

  /// Recalcula resultados con el directorio cargado. [kind] solo reemplaza la
  /// categoría actual cuando [replaceKind] es verdadero (null la quita).
  DestinationSearchState _refreshed({
    DirectoryStatus? status,
    String? query,
    DestinationKind? kind,
    bool replaceKind = false,
  }) {
    final nextQuery = query ?? state.query;
    final nextKind = replaceKind ? kind : state.kind;
    final result = _facade.search(nextQuery, kind: nextKind);
    final counts = <DestinationKind, int>{};
    for (final d in _facade.search(nextQuery).matches) {
      counts[d.kind] = (counts[d.kind] ?? 0) + 1;
    }
    return state.copyWith(
      status: status,
      query: nextQuery,
      kind: () => nextKind,
      matches: result.matches,
      suggestion: () => result.suggestion,
      recents: _facade.recents,
      kindCounts: counts,
    );
  }
}
