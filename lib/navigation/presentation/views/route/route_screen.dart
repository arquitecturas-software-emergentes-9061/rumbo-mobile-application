import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/navigation/application/indoor_navigation_cubit.dart';
import 'indoor_navigation_view.dart';
import '../../../domain/entities/destination.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rumbo_mobile_application/navigation/application/ar_prototype_facade.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ar_demo_instruction.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ar_platform_bridge.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({this.destination, super.key});
  final Destination? destination;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: IndoorNavigationView(
          navigation: serviceLocator<IndoorNavigationCubit>(),
          destination: destination,
        ),
      ),
      if (kDebugMode)
        TextButton(
          onPressed: () => context.push('/developer/ar'),
          child: const Text('Herramientas de diagnóstico AR'),
        ),
    ],
  );
}

class ArDiagnosticsScreen extends StatefulWidget {
  const ArDiagnosticsScreen({super.key});

  @override
  State<ArDiagnosticsScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<ArDiagnosticsScreen> {
  final _ar = const ArPrototypeFacade(ArPlatformBridge());
  StreamSubscription<Map<Object?, Object?>>? _events;
  double _heading = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    if (kDebugMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _events = _ar.events.listen(
        (event) {
          if (!mounted) return;
          setState(
            () => _status = '${event['state'] ?? ''}: ${event['reason'] ?? ''}',
          );
        },
        onError: (Object error) {
          if (mounted) {
            setState(() => _status = 'Error de comunicación AR: $error');
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _openDemo() async {
    setState(() => _status = 'Abriendo prototipo AR…');
    try {
      await _ar.open(ArDemoInstruction(headingDegrees: _heading));
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _status = error.message ?? 'No se pudo abrir AR.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'No se pudo abrir AR: $error');
      }
    }
  }

  Future<void> _exportTracking() async {
    try {
      final saved = await _ar.exportTrackingCsv();
      if (mounted) {
        setState(
          () => _status = saved
              ? 'Registro AR exportado.'
              : 'Exportación cancelada.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () =>
              _status = error.message ?? 'No se pudo exportar el registro AR.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'No se pudo exportar el registro AR: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final arAvailable =
        kDebugMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico AR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (arAvailable) ...[
              const Text('Coloca una flecha de prueba en el piso.'),
              Text('Dirección: ${_heading.round()}°'),
              Slider(
                value: _heading,
                max: 359,
                divisions: 359,
                onChanged: (value) => setState(() => _heading = value),
              ),
              OutlinedButton.icon(
                onPressed: _openDemo,
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Abrir prueba AR'),
              ),
              OutlinedButton.icon(
                onPressed: _exportTracking,
                icon: const Icon(Icons.save_alt),
                label: const Text('Exportar registro AR'),
              ),
              if (_status.isNotEmpty) Text(_status),
            ] else
              const Text(
                'La prueba AR está disponible en Android en modo debug.',
              ),
          ],
        ),
      ),
    );
  }
}
