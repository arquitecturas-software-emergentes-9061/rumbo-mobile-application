import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';

/// Búsqueda sobre el directorio, sin dependencias de Flutter ni de red.
class DestinationSearchService {
  const DestinationSearchService();

  /// Destinos cuyo texto contiene todas las palabras de [query]
  /// (sin distinguir mayúsculas ni tildes), filtrados por [kind] si se indica.
  List<Destination> search(
    List<Destination> directory,
    String query, {
    DestinationKind? kind,
  }) {
    final tokens = normalize(query).split(' ').where((t) => t.isNotEmpty).toList();
    return directory.where((d) {
      if (kind != null && d.kind != kind) return false;
      if (tokens.isEmpty) return true;
      final haystack = _haystack(d);
      return tokens.every(haystack.contains);
    }).toList();
  }

  /// Destino parecido a [query] cuando la búsqueda exacta no devuelve nada
  /// ("¿Quisiste decir Cardiología?"). Tolera hasta 2 errores de escritura.
  Destination? suggest(List<Destination> directory, String query) {
    final q = normalize(query);
    if (q.length < 3) return null;
    Destination? best;
    var bestDistance = 3;
    for (final d in directory) {
      for (final term in _terms(d)) {
        final distance = _levenshtein(q, term);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = d;
        }
      }
    }
    return best;
  }

  static String normalize(String input) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final out = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      out.write(index >= 0 ? to[index] : char);
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _haystack(Destination d) => normalize([
        d.name,
        d.specialist,
        d.room,
        d.kind.singularLabel,
        ...d.keywords,
      ].whereType<String>().join(' '));

  Iterable<String> _terms(Destination d) => [d.name, ...d.keywords]
      .expand((text) => normalize(text).split(' '))
      .where((term) => term.length >= 3);

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }
}
