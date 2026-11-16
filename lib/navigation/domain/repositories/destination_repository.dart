import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';

abstract interface class DestinationRepository {
  /// Directorio de destinos publicado para la sede actual.
  Future<List<Destination>> fetchDirectory();
}
