import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/destination_repository.dart';
import 'package:rumbo_mobile_application/navigation/domain/services/destination_search_service.dart';

class InvalidDestinationException implements Exception {
  const InvalidDestinationException(this.message);
  final String message;

  @override
  String toString() => 'InvalidDestinationException: $message';
}

class DestinationSearchResult {
  const DestinationSearchResult({required this.matches, this.suggestion});
  final List<Destination> matches;
  final Destination? suggestion;
}

/// Coordina el directorio, la búsqueda, la selección y los destinos recientes.
class DestinationSearchFacadeService {
  DestinationSearchFacadeService({
    required DestinationRepository repository,
    DestinationSearchService search = const DestinationSearchService(),
    this.maxRecents = 5,
  })  : _repository = repository,
        _search = search;

  final DestinationRepository _repository;
  final DestinationSearchService _search;
  final int maxRecents;

  List<Destination> _directory = const [];
  final List<Destination> _recents = [];

  List<Destination> get recents => List.unmodifiable(_recents);

  Future<List<Destination>> loadDirectory() async {
    _directory = await _repository.fetchDirectory();
    return _directory;
  }

  DestinationSearchResult search(String query, {DestinationKind? kind}) {
    final matches = _search.search(_directory, query, kind: kind);
    final suggestion = matches.isEmpty && query.trim().isNotEmpty
        ? _search.suggest(_directory, query)
        : null;
    return DestinationSearchResult(matches: matches, suggestion: suggestion);
  }

  /// Confirma que [destination] existe en el directorio cargado y es navegable.
  /// Lanza [InvalidDestinationException] en caso contrario.
  Destination select(Destination destination) {
    final inDirectory = _directory.where((d) => d.id == destination.id);
    if (inDirectory.isEmpty) {
      throw const InvalidDestinationException('El destino no está en el directorio.');
    }
    final current = inDirectory.first;
    if (!current.isValid) {
      throw const InvalidDestinationException(
        'El destino todavía no tiene una ruta disponible.',
      );
    }
    _recents
      ..removeWhere((d) => d.id == current.id)
      ..insert(0, current);
    if (_recents.length > maxRecents) _recents.removeLast();
    return current;
  }

  void clearRecents() => _recents.clear();
}
