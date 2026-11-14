import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rumbo_mobile_application/navigation/application/ar_prototype_facade.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ar_demo_instruction.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ar_platform_bridge.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/foundation_page.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _ar = const ArPrototypeFacade(ArPlatformBridge());
  StreamSubscription<Map<Object?, Object?>>? _events;
  double _heading = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _events = _ar.events.listen((event) {
        if (!mounted) return;
        setState(() => _status = '${event['state'] ?? ''}: ${event['reason'] ?? ''}');
      }, onError: (Object error) {
        if (mounted) setState(() => _status = 'Error de comunicación AR: $error');
      });
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _openDemo() async {
    try {
      await _ar.open(ArDemoInstruction(headingDegrees: _heading));
      if (mounted) setState(() => _status = 'Abriendo prototipo AR…');
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? 'No se pudo abrir AR.');
    } catch (error) {
      if (mounted) setState(() => _status = 'No se pudo abrir AR: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: FoundationPage(
          title: 'Tu ruta',
          description: 'Aquí se incorporarán el mapa y el guiado cuando se implementen sus historias.',
          icon: Icons.alt_route,
        )),
        if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Prototipo AR · dirección de demostración, sin ruta real'),
              Text('Dirección: ${_heading.round()}°'),
              Slider(value: _heading, max: 359, divisions: 359,
                onChanged: (value) => setState(() => _heading = value)),
              OutlinedButton.icon(onPressed: _openDemo,
                icon: const Icon(Icons.view_in_ar), label: const Text('Abrir prueba AR')),
              if (_status.isNotEmpty) Text(_status),
            ]),
          ),
      ],
    );
  }
}
