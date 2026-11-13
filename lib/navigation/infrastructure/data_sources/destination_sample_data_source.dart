import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/destination_model.dart';

/// Directorio de ejemplo para desarrollar sin la API (los datos reflejan los mockups).
/// Se activa con `--dart-define=RUMBO_USE_SAMPLE_DIRECTORY=true`.
class DestinationSampleDataSource implements DestinationDataSource {
  const DestinationSampleDataSource();

  @override
  Future<List<DestinationModel>> fetchDirectory() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const [
      DestinationModel(
        id: 'spec-cardiologia',
        name: 'Cardiología — Consultorio 204',
        kind: 'SPECIALTY',
        floor: 2,
        zone: 'Zona B',
        room: '204',
        siteName: 'Sede Central',
        specialist: 'Dra. Ana Torres',
        referencePoint: 'Cerca del Ascensor A',
        estimatedMinutes: 3,
        distanceMeters: 120,
        accessibleRouteNote: 'Ruta accesible disponible por el Ascensor A',
        keywords: ['corazon'],
      ),
      DestinationModel(
        id: 'doc-ana-torres',
        name: 'Dra. Ana Torres — Cardiología',
        kind: 'DOCTOR',
        floor: 2,
        zone: 'Zona B',
        room: '204',
        siteName: 'Sede Central',
        specialist: 'Dra. Ana Torres',
        referencePoint: 'Cerca del Ascensor A',
        estimatedMinutes: 3,
        distanceMeters: 120,
        accessibleRouteNote: 'Ruta accesible disponible por el Ascensor A',
      ),
      DestinationModel(
        id: 'lab-central',
        name: 'Laboratorio',
        kind: 'LABORATORY',
        floor: 1,
        zone: 'Hall central',
        siteName: 'Sede Central',
        referencePoint: 'Frente a admisión',
        estimatedMinutes: 2,
        distanceMeters: 60,
        keywords: ['analisis', 'muestras', 'sangre'],
      ),
      DestinationModel(
        id: 'pharmacy-main',
        name: 'Farmacia',
        kind: 'PHARMACY',
        floor: 1,
        zone: 'Ala este',
        siteName: 'Sede Central',
        referencePoint: 'Junto a la entrada principal',
        estimatedMinutes: 1,
        distanceMeters: 30,
        keywords: ['medicinas', 'recetas'],
      ),
      DestinationModel(
        id: 'imaging-rx',
        name: 'Imágenes',
        kind: 'IMAGING',
        floor: 1,
        zone: 'Ala oeste',
        siteName: 'Sede Central',
        estimatedMinutes: 4,
        distanceMeters: 150,
        keywords: ['rayos x', 'ecografia', 'resonancia'],
      ),
      DestinationModel(
        id: 'service-informes',
        name: 'Módulo de informes',
        kind: 'SERVICE',
        floor: 1,
        zone: 'Hall principal',
        siteName: 'Sede Central',
        estimatedMinutes: 1,
        distanceMeters: 35,
        keywords: ['ayuda', 'informacion', 'orientacion'],
      ),
    ];
  }
}
