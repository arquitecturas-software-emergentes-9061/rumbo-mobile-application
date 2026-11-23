import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/destination.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../application/indoor_navigation_cubit.dart';
import '../../../domain/entities/indoor_navigation.dart';
import '../../../infrastructure/data_sources/ar_platform_bridge.dart';

class IndoorNavigationView extends StatefulWidget {
  const IndoorNavigationView({
    required this.navigation,
    this.destination,
    super.key,
  });
  final IndoorNavigationCubit navigation;
  final Destination? destination;
  @override
  State<IndoorNavigationView> createState() => _IndoorNavigationViewState();
}

class _IndoorNavigationViewState extends State<IndoorNavigationView> {
  final _site = TextEditingController(), _destination = TextEditingController();
  StreamSubscription<Map<Object?, Object?>>? _tracking;
  final _ar = const ArPlatformBridge();
  bool _avoidStairs = false;
  @override
  void initState() {
    super.initState();
    _site.text = widget.destination?.siteId ?? '';
    _destination.text = widget.destination?.nodeId ?? '';
    _tracking = _ar.events.listen(
      (event) {
        if (widget.navigation.state.sessionId.isEmpty) return;
        final accepted = widget.navigation.tracking(event);
        if (accepted && {'limited', 'lost'}.contains(event['state'])) {
          unawaited(_ar.suspend().catchError((Object _) {}));
        }
      },
      onError: (Object error) {
        widget.navigation.tracking({
          'state': 'lost',
          'timestampUtc': DateTime.now().toUtc().toIso8601String(),
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant IndoorNavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != oldWidget.destination &&
        widget.navigation.state.sessionId.isEmpty) {
      _site.text = widget.destination?.siteId ?? '';
      _destination.text = widget.destination?.nodeId ?? '';
    }
  }

  @override
  void dispose() {
    _tracking?.cancel();
    _site.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<IndoorNavigationCubit, IndoorNavigationState>(
    bloc: widget.navigation,
    builder: (context, state) {
      final color = Theme.of(context).colorScheme;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tu recorrido',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    state.quality == LocationQuality.located
                        ? Icons.location_on
                        : Icons.location_searching,
                    color: color.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(switch (state.quality) {
                    LocationQuality.searching => 'Buscando tu ubicación',
                    LocationQuality.located => 'Ubicación detectada',
                    LocationQuality.lowConfidence => 'Ubicación no confiable',
                    LocationQuality.signalLost => 'Señal perdida',
                    LocationQuality.error => 'No pudimos localizarte',
                  }, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Semantics(liveRegion: true, child: Text(state.message)),
                  if (state.recalculating)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          if (state.sessionId.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Selecciona un destino del directorio para comenzar. Necesitamos reconocer tu ubicación antes de guiarte.',
            ),
            if (kDebugMode) ...[
              TextField(
                controller: _site,
                decoration: const InputDecoration(
                  labelText: 'Identificador de sede',
                ),
              ),
              TextField(
                controller: _destination,
                decoration: const InputDecoration(
                  labelText: 'Nodo destino publicado',
                ),
              ),
              SwitchListTile(
                title: const Text('Evitar escaleras'),
                value: _avoidStairs,
                onChanged: (v) => setState(() => _avoidStairs = v),
              ),
            ],
            FilledButton.icon(
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Buscar mi ubicación'),
              onPressed: () {
                if (_site.text.trim().isEmpty ||
                    _destination.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Selecciona un destino con sede y nodo publicados.',
                      ),
                    ),
                  );
                  return;
                }
                unawaited(
                  widget.navigation.start(
                    NavigationTarget(
                      siteId: _site.text.trim(),
                      nodeId: _destination.text.trim(),
                      name: widget.destination?.name ?? 'Destino seleccionado',
                      preferences: MobilityPreferences(
                        avoidStairs: _avoidStairs,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          if (state.position != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Piso: ${state.position!.floorId} · referencia: ${state.position!.nodeId}',
              ),
            ),
          if (state.routeInvalid && !state.recalculating)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay una ruta vigente para continuar. Revisa tu ubicación y reintenta.',
                ),
              ),
            ),
          if (state.route != null) ...[
            if (state.routeInvalid)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Ruta suspendida. Espera una nueva ruta válida antes de continuar.',
                  ),
                ),
              ),
            SizedBox(
              height: 320,
              child: Semantics(
                label: 'Mapa de la ruta publicada en el piso actual',
                child: CustomPaint(painter: IndoorRoutePainter(state)),
              ),
            ),
            LinearProgressIndicator(value: state.progress?.fraction ?? 0),
            Text('Destino: ${state.target?.name ?? ''}'),
          ],
          if (state.mode == GuidanceMode.fallback)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Continuamos en 2D. Se conservan tu destino y recorrido. Para AR necesitas recuperar y alinear la referencia espacial.',
                ),
              ),
            ),
          if (state.sessionId.isNotEmpty) ...[
            TextButton(
              onPressed: () async {
                final target = state.target;
                await widget.navigation.stop();
                if (target != null) await widget.navigation.start(target);
              },
              child: const Text('Volver a localizar'),
            ),
            OutlinedButton(
              onPressed:
                  state.quality == LocationQuality.located &&
                      !state.recalculating
                  ? () => widget.navigation.recalculate(retry: true)
                  : null,
              child: const Text('Reintentar ruta'),
            ),
            TextButton(
              onPressed: () => widget.navigation.stop(),
              child: const Text('Finalizar recorrido'),
            ),
            const Text(
              'AR de navegación requiere una referencia espacial alineada con el plano. El diagnóstico AR permanece disponible por separado.',
            ),
          ],
        ],
      );
    },
  );
}

class IndoorRoutePainter extends CustomPainter {
  IndoorRoutePainter(this.state);
  final IndoorNavigationState state;
  @override
  void paint(Canvas canvas, Size size) {
    final route = state.route;
    if (route == null || state.position == null) return;
    final position = state.position!;
    final nodes = route.nodes
        .where(
          (n) =>
              n.floorId == position.floorId &&
              n.planVersionId == position.planVersionId,
        )
        .toList();
    if (nodes.isEmpty) return;
    final xs = [...nodes.map((n) => n.x), position.x],
        ys = [...nodes.map((n) => n.y), position.y];
    final minX = xs.reduce(math.min), minY = ys.reduce(math.min);
    final width = math.max(1.0, xs.reduce(math.max) - minX),
        height = math.max(1.0, ys.reduce(math.max) - minY);
    final scale = math.min(
      (size.width - 40) / width,
      (size.height - 40) / height,
    );
    Offset point(double x, double y) =>
        Offset(20 + (x - minX) * scale, 20 + (y - minY) * scale);
    final paint = Paint()
      ..color = state.routeInvalid ? Colors.grey : const Color(0xFF3658E8)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < route.nodes.length - 1; i++) {
      final a = route.nodes[i], b = route.nodes[i + 1];
      if (a.floorId != position.floorId ||
          b.floorId != position.floorId ||
          a.planVersionId != position.planVersionId ||
          b.planVersionId != position.planVersionId) {
        continue;
      }
      paint.strokeWidth = i == state.progress?.segmentIndex ? 8 : 4;
      canvas.drawLine(point(a.x, a.y), point(b.x, b.y), paint);
    }
    for (final n in nodes) {
      canvas.drawCircle(point(n.x, n.y), 5, paint);
    }
    final last = route.nodes.last;
    if (last.floorId == position.floorId) {
      canvas.drawCircle(
        point(last.x, last.y),
        10,
        Paint()..color = Colors.green,
      );
    }
    if (state.canGuide) {
      canvas.drawCircle(
        point(position.x, position.y),
        9,
        Paint()..color = Colors.orange,
      );
    }
  }

  @override
  bool shouldRepaint(covariant IndoorRoutePainter oldDelegate) =>
      oldDelegate.state != state;
}
