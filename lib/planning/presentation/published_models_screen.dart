import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../injections.dart';
import '../domain/published_indoor_model.dart';
import 'published_model_sync_cubit.dart';

class PublishedModelsScreen extends StatelessWidget {
  const PublishedModelsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => serviceLocator<PublishedModelSyncCubit>()..loadSites(),
    child: const _PublishedModelsView(),
  );
}

class _PublishedModelsView extends StatefulWidget {
  const _PublishedModelsView();
  @override
  State<_PublishedModelsView> createState() => _PublishedModelsViewState();
}

class _PublishedModelsViewState extends State<_PublishedModelsView>
    with WidgetsBindingObserver {
  String? _floorId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PublishedModelSyncCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mapas publicados')),
    body: BlocBuilder<PublishedModelSyncCubit, ModelSyncState>(
      builder: (context, state) {
        final sync = context.read<PublishedModelSyncCubit>();
        final busy =
            state.phase == ModelSyncPhase.loadingSites ||
            state.phase == ModelSyncPhase.syncing;
        final model = state.model;
        return RefreshIndicator(
          onRefresh: sync.loadSites,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Consulta los pisos y destinos del mapa oficial de la sede.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              if (state.sites.isNotEmpty)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sede',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: state.siteId,
                      items: state.sites
                          .map(
                            (site) => DropdownMenuItem(
                              value: site.id,
                              child: Text(site.name),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (id) {
                              if (id != null) {
                                _floorId = null;
                                sync.selectSite(id);
                              }
                            },
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  state.phase == ModelSyncPhase.loadingSites
                      ? 'Buscando sedes con mapa oficial…'
                      : 'Comprobando la versión oficial…',
                  semanticsLabel: 'Sincronización en curso',
                ),
              ],
              if (state.phase == ModelSyncPhase.empty) ...[
                const Text(
                  'Todavía no hay sedes con un mapa publicado disponible.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: sync.loadSites,
                  child: const Text('Volver a comprobar'),
                ),
              ],
              if (state.phase == ModelSyncPhase.error) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(state.message ?? 'No se pudo comprobar el mapa.'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No se mostrará una versión anterior como vigente. Vuelve a sincronizar para continuar.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: sync.loadSites,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar sincronización'),
                ),
              ],
              if (model != null && state.phase == ModelSyncPhase.ready)
                ..._model(context, state, model),
              if (state.phase == ModelSyncPhase.ready) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: sync.refresh,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar mapa'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  List<Widget> _model(
    BuildContext context,
    ModelSyncState state,
    PublishedIndoorModel model,
  ) {
    if (!model.plans.any((plan) => plan.floorId == _floorId)) {
      _floorId = model.plans.first.floorId;
    }
    final plan = model.plans.firstWhere((plan) => plan.floorId == _floorId);
    final destinations =
        model.destinations.where((entry) => entry.floorId == _floorId).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final checkedAt = state.checkedAt == null
        ? ''
        : TimeOfDay.fromDateTime(state.checkedAt!).format(context);
    return [
      Semantics(
        liveRegion: true,
        child: Text(
          state.versionChanged
              ? 'Hay una nueva versión oficial. Los pisos y destinos ya se actualizaron.'
              : 'Versión oficial comprobada a las $checkedAt.',
        ),
      ),
      const SizedBox(height: 16),
      InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Piso',
          border: OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _floorId,
            items: model.plans
                .map(
                  (plan) => DropdownMenuItem(
                    value: plan.floorId,
                    child: Text(plan.name),
                  ),
                )
                .toList(),
            onChanged: (id) => setState(() => _floorId = id),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text('Modelo publicado', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: (plan.widthUnits / plan.heightUnits).clamp(.7, 1.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Semantics(
            label:
                'Modelo de ${plan.name}. Accesos, conexiones y destinos del mapa oficial.',
            child: ClipRect(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CustomPaint(
                  painter: _ModelPainter(
                    model,
                    plan,
                    Theme.of(context).colorScheme,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Amplía el modelo con dos dedos. Los accesos son verdes y los destinos azules.',
      ),
      const SizedBox(height: 20),
      Text(
        'Destinos de este piso',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (destinations.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Este piso no registra destinos.'),
        ),
      ...destinations.map(
        (destination) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined),
          title: Text(destination.name),
        ),
      ),
    ];
  }
}

class _ModelPainter extends CustomPainter {
  _ModelPainter(this.model, this.plan, this.colors);
  final PublishedIndoorModel model;
  final PublishedPlan plan;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      (size.width - 32) / plan.widthUnits,
      (size.height - 32) / plan.heightUnits,
    );
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(
      (size.width - plan.widthUnits * scale) / 2,
      (size.height - plan.heightUnits * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()
      ..color = colors.onSurface
      ..strokeWidth = 2 / scale;
    final walls = model.walls.where(
      (wall) => wall.planVersionId == plan.planVersionId,
    );
    for (final wall in walls) {
      canvas.drawLine(
        Offset(wall.x1, wall.y1),
        Offset(wall.x2, wall.y2),
        paint,
      );
      for (final door in model.doors.where((door) => door.wallId == wall.id)) {
        final gap = Paint()
          ..color = colors.surface
          ..strokeWidth = 4 / scale;
        canvas.drawLine(
          Offset(
            wall.x1 + (wall.x2 - wall.x1) * door.from,
            wall.y1 + (wall.y2 - wall.y1) * door.from,
          ),
          Offset(
            wall.x1 + (wall.x2 - wall.x1) * door.to,
            wall.y1 + (wall.y2 - wall.y1) * door.to,
          ),
          gap,
        );
      }
    }
    final nodes = {
      for (final node in model.nodes.where(
        (node) => node.planVersionId == plan.planVersionId,
      ))
        node.id: node,
    };
    paint.color = colors.primary;
    for (final link in model.connections) {
      final source = nodes[link.sourceNodeId],
          target = nodes[link.targetNodeId];
      if (source != null && target != null) {
        canvas.drawLine(
          Offset(source.x, source.y),
          Offset(target.x, target.y),
          paint,
        );
      }
    }
    for (final node in nodes.values) {
      paint.color = node.type == 'ACCESS'
          ? const Color(0xFF18723A)
          : colors.primary;
      canvas.drawCircle(
        Offset(node.x, node.y),
        (node.type == 'DESTINATION' ? 5 : 3) / scale,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ModelPainter oldDelegate) =>
      oldDelegate.model != model ||
      oldDelegate.plan != plan ||
      oldDelegate.colors != colors;
}
