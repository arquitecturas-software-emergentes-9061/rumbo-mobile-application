import 'package:flutter/material.dart';

class RoutePreferenceControls extends StatelessWidget {
  const RoutePreferenceControls({
    required this.avoidStairs,
    required this.simplerRoute,
    required this.voiceGuidance,
    this.onAvoidStairsChanged,
    this.onSimplerRouteChanged,
    this.onVoiceGuidanceChanged,
    super.key,
  });

  final bool avoidStairs;
  final bool simplerRoute;
  final bool voiceGuidance;
  final ValueChanged<bool>? onAvoidStairsChanged;
  final ValueChanged<bool>? onSimplerRouteChanged;
  final ValueChanged<bool>? onVoiceGuidanceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREFERENCIAS DE RUTA',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SwitchListTile(
          title: const Text('Evitar escaleras'),
          subtitle: const Text('Usa solo ascensores y rampas.'),
          value: avoidStairs,
          onChanged: onAvoidStairsChanged,
        ),
        SwitchListTile(
          title: const Text('Ruta más simple'),
          subtitle: const Text(
            'Prefiere menos giros y cambios de piso, aunque el trayecto sea más largo. El cálculo de rutas aún no aplica esta preferencia.',
          ),
          value: simplerRoute,
          onChanged: onSimplerRouteChanged,
        ),
        SwitchListTile(
          title: const Text('Indicaciones por voz'),
          subtitle: const Text('Escucha las indicaciones paso a paso.'),
          value: voiceGuidance,
          onChanged: onVoiceGuidanceChanged,
        ),
      ],
    );
  }
}
