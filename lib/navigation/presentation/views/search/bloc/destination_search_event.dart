import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';

sealed class DestinationSearchEvent {
  const DestinationSearchEvent();
}

final class DirectoryRequested extends DestinationSearchEvent {
  const DirectoryRequested();
}

final class QueryChanged extends DestinationSearchEvent {
  const QueryChanged(this.query);
  final String query;
}

/// Pulsar una categoría; pulsarla de nuevo la quita.
final class CategoryToggled extends DestinationSearchEvent {
  const CategoryToggled(this.kind);
  final DestinationKind kind;
}

final class DestinationSelected extends DestinationSearchEvent {
  const DestinationSelected(this.destination);
  final Destination destination;
}

/// La pantalla ya atendió la selección (navegó o mostró el error).
final class SelectionHandled extends DestinationSearchEvent {
  const SelectionHandled();
}

final class RecentsCleared extends DestinationSearchEvent {
  const RecentsCleared();
}

/// "¿Necesitas ayuda inmediata?": guía al módulo de informes más cercano.
final class HelpRequested extends DestinationSearchEvent {
  const HelpRequested();
}
