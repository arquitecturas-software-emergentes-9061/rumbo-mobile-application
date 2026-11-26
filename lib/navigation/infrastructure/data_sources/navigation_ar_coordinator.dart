import 'dart:async';

import 'package:flutter/services.dart';

import '../../application/indoor_navigation_cubit.dart';
import '../../domain/entities/indoor_navigation.dart';
import 'ar_platform_bridge.dart';

/// Synchronizes one Android AR presentation with the persistent Flutter session.
class NavigationArCoordinator {
  NavigationArCoordinator(this.navigation, this.bridge) {
    _events = bridge.events.listen(
      (event) => unawaited(_onEvent(event)),
      onError: (Object _) {
        if (active) {
          unawaited(_fallback('Se perdió la conexión con la cámara.'));
        }
      },
    );
    _states = navigation.stream.listen((state) => unawaited(_onState(state)));
  }

  final IndoorNavigationCubit navigation;
  final ArPlatformBridge bridge;
  late final StreamSubscription<Map<Object?, Object?>> _events;
  late final StreamSubscription<IndoorNavigationState> _states;
  Timer? _deadline;
  bool active = false, _ready = false, _normal = false, _everTracked = false;
  int _generation = 0;
  String? _arSession;
  PublishedRoute? _route;
  List<RouteNode> _nodes = [];
  Map<String, Object> _context = {};
  DateTime? _sentFix;
  int? _progressSent;
  String _status = 'Preparando cámara…';

  Future<void> open() async {
    if (active || !bridge.isSupportedPlatform || !navigation.canOpenAr) return;
    final state = navigation.state;
    final position = state.position!;
    final route = state.route!;
    final start = state.progress?.nodeIndex ?? 0;
    final origin = route.nodes[start];
    if (origin.floorId != position.floorId ||
        origin.planVersionId != position.planVersionId) {
      return;
    }
    final nodes = route.nodes
        .skip(start)
        .takeWhile(
          (node) =>
              node.floorId == origin.floorId &&
              node.planVersionId == origin.planVersionId,
        )
        .toList();
    if (nodes.length < 2) {
      navigation.returnToMap('Completa el cambio de piso en el mapa 2D.');
      return;
    }
    final generation = ++_generation;
    _arSession = '${state.sessionId}-ar-$generation';
    _context = {
      'protocolVersion': 1,
      'sessionId': _arSession!,
      'siteId': route.siteId,
      'floorId': origin.floorId,
      'mapVersion': route.modelVersionId,
    };
    _route = route;
    _nodes = nodes;
    _ready = _normal = _everTracked = false;
    _sentFix = null;
    _progressSent = 0;
    _status = 'Preparando cámara…';
    active = true;
    navigation.arOpened();
    try {
      await bridge.openNavigation(state.target?.name ?? 'Tu destino');
      if (_generation != generation) return;
      if (!active) {
        await bridge.suspend();
      } else if (!_everTracked) {
        _scheduleFallback(
          const Duration(seconds: 18),
          'La cámara no pudo iniciar el tracking. Continúa en 2D.',
        );
      }
    } catch (error) {
      if (active && _generation == generation) {
        final message =
            error is PlatformException &&
                error.code == 'CAMERA_PERMISSION_REQUIRED'
            ? error.message
            : null;
        await _fallback(
          message ?? 'La guía AR no está disponible en este dispositivo.',
          suspend: false,
        );
      }
    }
  }

  Future<void> _onEvent(Map<Object?, Object?> event) async {
    if (!active) return;
    final state = event['state'];
    final reason = event['reason']?.toString() ?? '';
    final parts = <String, String>{};
    for (final part in reason.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) parts[part.substring(0, i)] = part.substring(i + 1);
    }
    if (parts.containsKey('sessionId') && parts['sessionId'] != _arSession) {
      return;
    }
    try {
      switch (state) {
        case 'navigation_ready' when reason == 'android_host':
          if (_ready) return;
          await bridge.send('ReceiveRoute', {
            ..._context,
            'routeId': _arSession!,
            'revision': 1,
            'originNodeId': _nodes.first.id,
            'destinationNodeId': _nodes.last.id,
            'activeNodeId': _nodes[1].id,
            'nodes': [
              for (final node in _nodes)
                {
                  'nodeId': node.id,
                  'floorId': node.floorId,
                  'position': [node.x, -node.y, 0],
                },
            ],
          });
        case 'route_accepted':
          _ready = true;
          await _sendFix(navigation.state);
        case 'normal':
          _normal = _everTracked = true;
          if (navigation.state.spatialReferenceReady) {
            _deadline?.cancel();
            await _setStatus('Tracking recuperado.');
          } else {
            _scheduleFallback(
              const Duration(seconds: 50),
              'No hay una referencia AR confiable. Continúa en 2D.',
            );
            await _setStatus('Apunta la cámara al suelo.');
          }
          await _sendFix(navigation.state);
        case 'lost':
        case 'limited':
          _normal = false;
          if (_everTracked) {
            await _setStatus('Recuperando el tracking…');
            _scheduleFallback(
              const Duration(seconds: 2),
              'Se perdió el tracking. Continúa en 2D.',
            );
          }
        case 'unsupported':
        case 'permission_denied':
          await _fallback('No se pudo activar la cámara. Continúa en 2D.');
        case 'closed':
        case 'show_map':
          await _fallback('Continúa tu recorrido en 2D.', suspend: false);
        case 'end_navigation':
          await _fallback('Recorrido finalizado.', suspend: false);
          await navigation.stop();
        case 'calibration_walk':
          await _setStatus(
            'Camina hacia otra referencia con la cámara apuntando al suelo.',
          );
        case 'calibration_accepted':
          navigation.arCalibrated();
          _deadline?.cancel();
          await _setStatus('Guía AR activa');
        case 'calibration_required':
          navigation.arCalibrationLost();
          _sentFix = null;
          await _setStatus('Buscando una referencia para recalibrar…');
          _scheduleFallback(
            const Duration(seconds: 45),
            'No se pudo recalibrar. Continúa en 2D.',
          );
        case 'recalibrate':
          await bridge.send('InvalidateCalibration', 'user_requested');
        case 'segment_changed':
        case 'arrived':
          final node = parts['activeNodeId'];
          if (node == null) return;
          navigation.acceptArProgress(node, arrived: state == 'arrived');
          if (state == 'arrived') {
            await _fallback(
              node == _route?.nodes.last.id
                  ? 'Has llegado a tu destino.'
                  : 'Completa el cambio de piso en 2D.',
            );
          }
        case 'guidance':
          final text = switch (parts['turn']) {
            'left' => 'Gira a la izquierda',
            'right' => 'Gira a la derecha',
            'around' => 'Da media vuelta',
            _ => 'Avanza recto',
          };
          final meters = int.tryParse(parts['meters'] ?? '');
          await _setStatus(meters == null ? text : '$text · $meters m');
        case 'navigation_guide':
          if (reason.contains('no_surface') ||
              reason.contains('anchor_unavailable')) {
            await _setStatus('Apunta la cámara al suelo para ver la guía.');
          }
        case 'navigation_error' when !_ready:
          await _fallback('La ruta no pudo cargarse en AR. Continúa en 2D.');
      }
    } catch (_) {
      if (active) {
        await _fallback('No se pudo sincronizar la guía AR. Continúa en 2D.');
      }
    }
  }

  Future<void> _onState(IndoorNavigationState state) async {
    if (!active || !identical(state, navigation.state)) return;
    final position = state.position;
    if (state.progress?.fraction == 1) {
      await _fallback('Has llegado a tu destino.');
      return;
    }
    if (state.mode != GuidanceMode.ar ||
        !identical(state.route, _route) ||
        position?.floorId != _context['floorId'] ||
        position?.planVersionId != _nodes.first.planVersionId) {
      final message = state.routeInvalid
          ? state.message
          : 'Continúa en el mapa 2D.';
      await _fallback(message);
      return;
    }
    try {
      await _sendFix(state);
      if (!active) return;
      final progress = state.progress;
      if (_ready &&
          _normal &&
          state.spatialReferenceReady &&
          progress != null) {
        final reached = state.route!.nodes[progress.nodeIndex].id;
        final index = _nodes.indexWhere((node) => node.id == reached);
        if (index > (_progressSent ?? 0) && index < _nodes.length - 1) {
          _progressSent = index;
          await bridge.send('ReceiveProgress', {
            ..._context,
            'routeId': _arSession!,
            'revision': 1,
            'activeNodeId': _nodes[index + 1].id,
            'state': 'navigating',
            'capturedAtUnixMs': DateTime.now().millisecondsSinceEpoch,
            'confidence': [.8],
          });
        }
      }
      await bridge.updateHud(
        _status,
        ((progress?.fraction ?? 0) * 100).round(),
      );
    } catch (_) {
      if (active) {
        await _fallback('No se pudo sincronizar la guía AR. Continúa en 2D.');
      }
    }
  }

  Future<void> _sendFix(IndoorNavigationState state) async {
    final pos = state.position;
    final scale = pos?.metersPerUnit;
    if (!active ||
        !_ready ||
        !_normal ||
        pos == null ||
        !pos.reliable ||
        scale == null ||
        !scale.isFinite ||
        scale <= 0 ||
        pos.observedAt == _sentFix) {
      return;
    }
    if (DateTime.now().difference(pos.observedAt) >
        const Duration(seconds: 2)) {
      return;
    }
    _sentFix = pos.observedAt;
    await bridge.send('ReceivePositionFix', {
      ..._context,
      'nodeId': pos.nodeId,
      'position': [pos.x, -pos.y, 0],
      'metersPerMapUnit': [scale],
      'capturedAtUnixMs': pos.observedAt.millisecondsSinceEpoch,
    });
  }

  Future<void> _setStatus(String status) async {
    _status = status;
    await bridge.updateHud(
      status,
      ((navigation.state.progress?.fraction ?? 0) * 100).round(),
    );
  }

  void _scheduleFallback(Duration duration, String message) {
    _deadline?.cancel();
    _deadline = Timer(duration, () => unawaited(_fallback(message)));
  }

  Future<void> _fallback(String message, {bool suspend = true}) async {
    if (!active) return;
    active = false;
    _deadline?.cancel();
    navigation.returnToMap(message, fallback: true);
    if (suspend) {
      try {
        await bridge.suspend();
      } catch (_) {}
    }
  }

  void dispose() {
    if (active) unawaited(_fallback('Continúa tu recorrido en 2D.'));
    _deadline?.cancel();
    unawaited(_events.cancel());
    unawaited(_states.cancel());
  }
}
