import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/presentation/utils/mockup_palette.dart';
import 'package:rumbo_mobile_application/navigation/presentation/widgets/navigation_chrome.dart';

/// Detalle del destino elegido, antes de iniciar el guiado (mockup MB-05).
class DestinationDetailScreen extends StatelessWidget {
  const DestinationDetailScreen({required this.destination, super.key});

  /// Nulo si se llega por un enlace directo sin pasar por la búsqueda.
  final Destination? destination;

  @override
  Widget build(BuildContext context) {
    final destination = this.destination;
    return Scaffold(
      backgroundColor: MockupPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const NavigationTopBar(),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go('/search'),
              icon: const Icon(Icons.chevron_left, color: MockupPalette.primary),
              label: const Text('Volver', style: TextStyle(color: MockupPalette.primary)),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            if (destination == null)
              const _Unavailable()
            else
              ..._content(context, destination),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, Destination d) {
    return [
      Container(
        height: 150,
        decoration: BoxDecoration(
          color: MockupPalette.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, color: MockupPalette.textMuted, size: 30),
            const SizedBox(height: 6),
            Text(
              d.room != null
                  ? 'Imagen: entrada del Consultorio ${d.room}'
                  : 'Imagen: entrada de ${d.name}',
              style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'DESTINO',
        style: TextStyle(
          color: MockupPalette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        d.name,
        style: const TextStyle(
          color: MockupPalette.primary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 18),
      _InfoRow(
        icon: Icons.apartment_outlined,
        label: 'Sede y piso',
        value: d.siteName == null
            ? 'Piso ${d.floor}'
            : 'Piso ${d.floor} • ${d.siteName}',
      ),
      if (d.specialist != null)
        _InfoRow(icon: Icons.person_outline, label: 'Especialista', value: d.specialist!),
      if (d.referencePoint != null)
        _InfoRow(
          icon: Icons.place_outlined,
          label: 'Punto de referencia',
          value: d.referencePoint!,
        ),
      const SizedBox(height: 14),
      if (d.estimatedMinutes != null)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MockupPalette.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: MockupPalette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.distanceMeters != null
                          ? 'Tiempo estimado: ${d.estimatedMinutes} min (${d.distanceMeters} m)'
                          : 'Tiempo estimado: ${d.estimatedMinutes} min',
                      style: const TextStyle(
                        color: MockupPalette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (d.accessibleRouteNote != null)
                      Text(
                        d.accessibleRouteNote!,
                        style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 22),
      SizedBox(
        height: 52,
        child: FilledButton(
          // El cálculo de ruta y el guiado pertenecen a otra historia; por ahora
          // se abre la pestaña Ruta.
          onPressed: () => context.go('/route'),
          style: FilledButton.styleFrom(
            backgroundColor: MockupPalette.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Iniciar navegación →', style: TextStyle(fontSize: 16)),
        ),
      ),
    ];
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MockupPalette.textMuted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: MockupPalette.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Text(
        'Este destino no está disponible. Vuelve a buscarlo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: MockupPalette.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
