import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/navigation/presentation/utils/mockup_palette.dart';

/// Barra superior de los mockups: logotipo, título, búsqueda y avatar.
class NavigationTopBar extends StatelessWidget {
  const NavigationTopBar({this.title = 'Navegar', super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.add_box_outlined, color: MockupPalette.primary, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MockupPalette.primary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.search, color: MockupPalette.primary, size: 24),
        const SizedBox(width: 16),
        const CircleAvatar(
          radius: 16,
          backgroundColor: MockupPalette.primary,
          child: Icon(Icons.person, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}

/// Tarjeta "¿Necesitas ayuda inmediata?" con acceso a guía.
class HelpCard extends StatelessWidget {
  const HelpCard({required this.onGuide, super.key});

  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MockupPalette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: MockupPalette.primary,
            child: Icon(Icons.support_agent, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Necesitas ayuda inmediata?',
                  style: TextStyle(
                    color: MockupPalette.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'El módulo de informes está cerca de ti',
                  style: TextStyle(color: MockupPalette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onGuide,
            style: FilledButton.styleFrom(
              backgroundColor: MockupPalette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Guía'),
          ),
        ],
      ),
    );
  }
}

/// Píldora de categoría o pestaña de resultados.
class CategoryPill extends StatelessWidget {
  const CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : MockupPalette.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? MockupPalette.primary : MockupPalette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  Icon(Icons.check, size: 16, color: foreground)
                else if (icon != null)
                  Icon(icon, size: 16, color: MockupPalette.textMuted),
                if (selected || icon != null) const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
