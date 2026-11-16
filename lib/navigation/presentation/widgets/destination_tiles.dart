import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/presentation/utils/mockup_palette.dart';

IconData iconForKind(DestinationKind kind) => switch (kind) {
      DestinationKind.specialty => Icons.favorite_border,
      DestinationKind.doctor => Icons.person_outline,
      DestinationKind.laboratory => Icons.science_outlined,
      DestinationKind.pharmacy => Icons.local_pharmacy_outlined,
      DestinationKind.imaging => Icons.image_outlined,
      DestinationKind.service => Icons.room_service_outlined,
    };

/// Fila de "Destinos recientes": historial, título, ubicación y flecha.
class RecentDestinationTile extends StatelessWidget {
  const RecentDestinationTile({required this.destination, required this.onTap, super.key});

  final Destination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: const _SquareIcon(icon: Icons.history),
      title: Text(
        destination.name,
        style: const TextStyle(color: MockupPalette.primary, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        destination.locationLabel,
        style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward, color: MockupPalette.textMuted, size: 20),
    );
  }
}

/// Tarjeta de resultado de búsqueda.
class DestinationResultCard extends StatelessWidget {
  const DestinationResultCard({required this.destination, required this.onTap, super.key});

  final Destination destination;
  final VoidCallback onTap;

  String get _subtitle {
    final d = destination;
    final parts = d.kind == DestinationKind.doctor && d.room != null
        ? ['Consultorio ${d.room}', 'Piso ${d.floor}', d.kind.singularLabel]
        : ['Piso ${d.floor}', d.kind.singularLabel, if (d.zone != null) d.zone!];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MockupPalette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SquareIcon(icon: iconForKind(destination.kind)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: const TextStyle(
                        color: MockupPalette.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MockupPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: MockupPalette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: MockupPalette.textMuted, size: 20),
    );
  }
}
