import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';

/// Modelo de transporte del directorio. Las claves son una suposición del
/// contrato REST de Planning/Navigation hasta que la API publique el endpoint.
class DestinationModel {
  const DestinationModel({
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
    this.navigable = true,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      floor: (json['floor'] as num).toInt(),
      zone: json['zone'] as String?,
      room: json['room'] as String?,
      siteName: json['siteName'] as String?,
      specialist: json['specialist'] as String?,
      referencePoint: json['referencePoint'] as String?,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      accessibleRouteNote: json['accessibleRouteNote'] as String?,
      keywords: ((json['keywords'] as List?) ?? const []).cast<String>(),
      navigable: json['navigable'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String kind;
  final int floor;
  final String? zone;
  final String? room;
  final String? siteName;
  final String? specialist;
  final String? referencePoint;
  final int? estimatedMinutes;
  final int? distanceMeters;
  final String? accessibleRouteNote;
  final List<String> keywords;
  final bool navigable;

  Destination toEntity() => Destination(
        id: id,
        name: name,
        kind: _kindFrom(kind),
        floor: floor,
        zone: zone,
        room: room,
        siteName: siteName,
        specialist: specialist,
        referencePoint: referencePoint,
        estimatedMinutes: estimatedMinutes,
        distanceMeters: distanceMeters,
        accessibleRouteNote: accessibleRouteNote,
        keywords: keywords,
        isNavigable: navigable,
      );

  static DestinationKind _kindFrom(String value) {
    switch (value.toUpperCase()) {
      case 'SPECIALTY':
        return DestinationKind.specialty;
      case 'DOCTOR':
        return DestinationKind.doctor;
      case 'LABORATORY':
        return DestinationKind.laboratory;
      case 'PHARMACY':
        return DestinationKind.pharmacy;
      case 'IMAGING':
        return DestinationKind.imaging;
      default:
        return DestinationKind.service;
    }
  }
}
