import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';

enum DirectoryStatus { loading, ready, failure }

class DestinationSearchState {
  const DestinationSearchState({
    this.status = DirectoryStatus.loading,
    this.query = '',
    this.kind,
    this.matches = const [],
    this.suggestion,
    this.recents = const [],
    this.kindCounts = const {},
    this.selection,
    this.selectionError,
  });

  final DirectoryStatus status;
  final String query;
  final DestinationKind? kind;
  final List<Destination> matches;
  final Destination? suggestion;
  final List<Destination> recents;

  /// Coincidencias por categoría ignorando el filtro de categoría activo.
  final Map<DestinationKind, int> kindCounts;

  /// Destino válido recién elegido; la pantalla navega al detalle y lo limpia.
  final Destination? selection;
  final String? selectionError;

  /// Hay una consulta o una categoría activa (si no, se muestra el inicio).
  bool get isSearching => query.trim().isNotEmpty || kind != null;
  bool get hasNoResults => isSearching && matches.isEmpty;

  int get totalCount => kindCounts.values.fold(0, (a, b) => a + b);

  DestinationSearchState copyWith({
    DirectoryStatus? status,
    String? query,
    DestinationKind? Function()? kind,
    List<Destination>? matches,
    Destination? Function()? suggestion,
    List<Destination>? recents,
    Map<DestinationKind, int>? kindCounts,
    Destination? Function()? selection,
    String? Function()? selectionError,
  }) {
    return DestinationSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      kind: kind != null ? kind() : this.kind,
      matches: matches ?? this.matches,
      suggestion: suggestion != null ? suggestion() : this.suggestion,
      recents: recents ?? this.recents,
      kindCounts: kindCounts ?? this.kindCounts,
      selection: selection != null ? selection() : this.selection,
      selectionError:
          selectionError != null ? selectionError() : this.selectionError,
    );
  }
}
