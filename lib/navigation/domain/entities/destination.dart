/// Categoría de un destino del directorio de la clínica.
enum DestinationKind {
  specialty('Especialidades', 'Especialidad'),
  doctor('Médicos', 'Médico'),
  laboratory('Laboratorio', 'Laboratorio'),
  pharmacy('Farmacia', 'Farmacia'),
  imaging('Imágenes', 'Imágenes'),
  service('Servicios', 'Servicio');

  const DestinationKind(this.categoryLabel, this.singularLabel);

  /// Texto de la categoría (chips de filtro).
  final String categoryLabel;

  /// Texto en singular (subtítulo de cada resultado).
  final String singularLabel;
}

/// Lugar al que el visitante puede pedir ser guiado.
///
/// Es una vista de solo lectura del modelo espacial publicado por Planning;
/// la app no edita destinos.
class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.kind,
    required this.floor,
    this.zone,
    this.room,
    this.siteName,
    this.specialist,
    this.referencePoint,
    this.estimatedMinutes,
    this.distanceMeters,
    this.accessibleRouteNote,
    this.keywords = const [],
    this.isNavigable = true,
    this.siteId,
    this.nodeId,
  });

  final String id;
  final String? siteId, nodeId;
  final String name;
  final DestinationKind kind;
  final int floor;
  final String? zone;
  final String? room;
  final String? siteName;
  final String? specialist;
  final String? referencePoint;
  final int? estimatedMinutes;
  final int? distanceMeters;
  final String? accessibleRouteNote;

  /// Sinónimos adicionales para la búsqueda (por ejemplo, la especialidad de un médico).
  final List<String> keywords;

  /// Falso si el destino existe en el directorio pero aún no tiene geometría navegable.
  final bool isNavigable;

  /// "Piso 2 · Zona B"
  String get locationLabel =>
      zone == null ? 'Piso $floor' : 'Piso $floor · $zone';

  /// Un destino es válido para iniciar guiado si tiene identidad y es navegable.
  bool get isValid =>
      id.trim().isNotEmpty && name.trim().isNotEmpty && isNavigable;
}
