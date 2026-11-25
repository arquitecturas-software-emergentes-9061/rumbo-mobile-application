import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/beacon_identifier.dart';
import '../domain/entities/ble_scan_event.dart';
import '../domain/entities/indoor_navigation.dart';
import '../domain/repositories/indoor_navigation_repository.dart';
import '../domain/services/rssi_window_service.dart';
import '../domain/services/route_tracking_service.dart';
import 'navigation_scan_service.dart';

class IndoorNavigationState {
  const IndoorNavigationState({
    this.sessionId = '',
    this.target,
    this.quality = LocationQuality.searching,
    this.position,
    this.route,
    this.progress,
    this.mode = GuidanceMode.map,
    this.message = 'Busca tu ubicación para comenzar.',
    this.recalculating = false,
    this.routeInvalid = false,
    this.spatialReferenceReady = false,
  });
  final String sessionId, message;
  final NavigationTarget? target;
  final LocationQuality quality;
  final IndoorPosition? position;
  final PublishedRoute? route;
  final RouteProgress? progress;
  final GuidanceMode mode;
  final bool recalculating, routeInvalid, spatialReferenceReady;
  bool get canGuide =>
      quality == LocationQuality.located && route != null && !routeInvalid;
  IndoorNavigationState copy({
    String? sessionId,
    NavigationTarget? target,
    LocationQuality? quality,
    IndoorPosition? position,
    PublishedRoute? route,
    RouteProgress? progress,
    GuidanceMode? mode,
    String? message,
    bool? recalculating,
    bool? routeInvalid,
    bool? spatialReferenceReady,
  }) => IndoorNavigationState(
    sessionId: sessionId ?? this.sessionId,
    target: target ?? this.target,
    quality: quality ?? this.quality,
    position: position ?? this.position,
    route: route ?? this.route,
    progress: progress ?? this.progress,
    mode: mode ?? this.mode,
    message: message ?? this.message,
    recalculating: recalculating ?? this.recalculating,
    routeInvalid: routeInvalid ?? this.routeInvalid,
    spatialReferenceReady: spatialReferenceReady ?? this.spatialReferenceReady,
  );
}

/// One session survives changes between Flutter map and Unity activities.
class IndoorNavigationCubit extends Cubit<IndoorNavigationState> {
  IndoorNavigationCubit(
    this.repository,
    this.scanner, {
    RssiWindowService? filter,
    DeviationService? deviation,
    DateTime Function()? clock,
    this.cooldown = const Duration(seconds: 15),
    this.fixLifetime = const Duration(seconds: 12),
  }) : filter = filter ?? RssiWindowService(window: const Duration(seconds: 5)),
       deviation = deviation ?? DeviationService(),
       clock = clock ?? DateTime.now,
       super(const IndoorNavigationState());
  final IndoorNavigationRepository repository;
  final NavigationScanService scanner;
  final RssiWindowService filter;
  final DeviationService deviation;
  final DateTime Function() clock;
  final Duration cooldown, fixLifetime;
  final _tracker = RouteTrackingService();
  StreamSubscription<BleScanEvent>? _ble;
  Timer? _timer;
  Set<BeaconIdentifier> _inventory = {};
  int _generation = 0, _routeRequest = 0;
  bool _resolving = false, _starting = false;
  DateTime? _lastResolution, _lastRouteRequest, _lastArEvent;

  Future<void> start(NavigationTarget target) async {
    if (_starting) return;
    if (state.sessionId.isNotEmpty) {
      if (state.target?.siteId == target.siteId &&
          state.target?.nodeId == target.nodeId) {
        return;
      }
      await stop();
      if (isClosed || _starting) return;
    }
    _starting = true;
    final generation = ++_generation;
    emit(
      IndoorNavigationState(
        sessionId: '${clock().microsecondsSinceEpoch}',
        target: target,
        message: 'Buscando balizas de la sede…',
      ),
    );
    await _startScanner(target, generation);
  }

  Future<void> relocate() async {
    final target = state.target;
    if (target == null || _starting) return;
    _starting = true;
    final generation = ++_generation;
    ++_routeRequest;
    _timer?.cancel();
    _timer = null;
    try {
      await _ble?.cancel();
      _ble = null;
      await scanner.stop();
      if (generation != _generation || isClosed) {
        _starting = false;
        return;
      }
      filter.clear();
      deviation.reset();
      _lastResolution = null;
      emit(
        state.copy(
          quality: LocationQuality.searching,
          mode: GuidanceMode.map,
          spatialReferenceReady: false,
          recalculating: false,
          message: 'Buscando una nueva referencia…',
        ),
      );
    } catch (error) {
      _starting = false;
      if (!isClosed && generation == _generation) _fail(error);
      return;
    }
    await _startScanner(target, generation);
  }

  Future<void> _startScanner(NavigationTarget target, int generation) async {
    try {
      _inventory = await repository.beacons(target.siteId);
      if (generation != _generation || isClosed) return;
      if (_inventory.isEmpty) {
        throw const NavigationFailure(
          'La sede no tiene balizas activas con identidad y referencia espacial.',
        );
      }
      _ble = scanner.events.listen(_onBle, onError: (Object e) => _fail(e));
      await scanner.start(_inventory);
      if (generation != _generation || isClosed) {
        await scanner.stop();
        return;
      }
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => tick());
    } catch (e) {
      if (generation == _generation && !isClosed) {
        await _ble?.cancel();
        _ble = null;
        _fail(e);
      }
    } finally {
      _starting = false;
    }
  }

  void _onBle(BleScanEvent event) {
    if (isClosed) return;
    if (event is BleObservationReceived) {
      if (filter.add(event.observation, clock(), _inventory)) {
        unawaited(resolve());
      }
    } else if (event is BleScanStatusChanged &&
        {
          'bluetoothOff',
          'permissionsDenied',
          'locationOff',
          'unsupported',
          'error',
        }.contains(event.status)) {
      deviation.reset();
      emit(
        state.copy(
          quality: LocationQuality.error,
          message: event.message.isEmpty
              ? 'Revisa Bluetooth, permisos y ubicación.'
              : event.message,
          mode: GuidanceMode.map,
          spatialReferenceReady: false,
        ),
      );
    }
  }

  void tick() {
    if (isClosed || state.sessionId.isEmpty) return;
    final samples = filter.snapshot(clock());
    if (state.quality == LocationQuality.error && samples.isEmpty) return;
    if ((samples.length < 2 && state.mode != GuidanceMode.ar) ||
        (state.position != null &&
            clock().difference(state.position!.observedAt) > fixLifetime)) {
      deviation.reset();
      emit(
        state.copy(
          quality: state.position == null
              ? LocationQuality.searching
              : LocationQuality.signalLost,
          mode: GuidanceMode.map,
          spatialReferenceReady: false,
          message: 'Señal insuficiente. Acércate a una referencia reconocida.',
        ),
      );
    }
    unawaited(resolve());
  }

  Future<void> resolve() async {
    if (isClosed ||
        _resolving ||
        state.target == null ||
        (_lastResolution != null &&
            clock().difference(_lastResolution!) <
                const Duration(seconds: 2))) {
      return;
    }
    final now = clock();
    final signals = filter
        .snapshot(now)
        .where(
          (beacon) =>
              beacon.filteredDeviation <= 6 &&
              now.difference(beacon.observedAt) <= const Duration(seconds: 2),
        )
        .toList();
    if (signals.length < 2) return;
    _resolving = true;
    _lastResolution = clock();
    final generation = _generation;
    try {
      final position = await repository.resolve(state.target!.siteId, signals);
      if (isClosed || generation != _generation) return;
      if (position == null) {
        deviation.reset();
        if (state.mode == GuidanceMode.ar &&
            state.position != null &&
            clock().difference(state.position!.observedAt) <= fixLifetime) {
          return;
        }
        emit(
          state.copy(
            quality: LocationQuality.lowConfidence,
            message:
                'Ubicación no confiable. Falta resolución espacial calibrada para esta sede.',
            mode: GuidanceMode.map,
            spatialReferenceReady: false,
          ),
        );
      } else {
        await acceptPosition(position);
      }
    } catch (e) {
      if (!isClosed && generation == _generation) _fail(e);
    } finally {
      _resolving = false;
    }
  }

  Future<void> acceptPosition(IndoorPosition position) async {
    final target = state.target;
    if (isClosed ||
        target == null ||
        position.siteId != target.siteId ||
        position.observedAt.isAfter(clock().add(const Duration(seconds: 2))) ||
        clock().difference(position.observedAt) > fixLifetime ||
        (state.position != null &&
            !position.observedAt.isAfter(state.position!.observedAt))) {
      return;
    }
    if (!position.reliable) {
      deviation.reset();
      emit(
        state.copy(
          quality: LocationQuality.lowConfidence,
          mode: GuidanceMode.map,
          spatialReferenceReady: false,
          message:
              'Ubicación no confiable. Detente y vuelve a buscar una referencia.',
        ),
      );
      return;
    }
    emit(
      state.copy(
        position: position,
        quality: LocationQuality.located,
        message: 'Ubicación detectada.',
      ),
    );
    if (state.route == null) {
      await recalculate();
      return;
    }
    final route = state.route!;
    if (route.modelVersionId != position.modelVersionId) {
      emit(
        state.copy(
          routeInvalid: true,
          spatialReferenceReady: false,
          message: 'El mapa cambió. Actualizando recorrido…',
        ),
      );
      await recalculate();
      return;
    }
    final progress = _tracker.match(route, position, previous: state.progress);
    if (progress != null &&
        (state.mode != GuidanceMode.ar ||
            progress.nodeIndex >= (state.progress?.nodeIndex ?? 0))) {
      emit(
        state.copy(
          progress: progress,
          message: progress.fraction == 1
              ? 'Has llegado a tu destino.'
              : progress.floorChanged
              ? 'Cambio de piso confirmado.'
              : 'Continúa por la ruta indicada.',
        ),
      );
    }
    if (progress == null && route.nodes.any((n) => n.id == position.nodeId)) {
      deviation.reset();
      emit(
        state.copy(
          quality: LocationQuality.lowConfidence,
          message: 'Confirma la referencia del piso antes de continuar.',
          mode: GuidanceMode.map,
          spatialReferenceReady: false,
        ),
      );
      return;
    }
    if (deviation.update(route, position)) {
      if (state.recalculating) return;
      emit(
        state.copy(
          routeInvalid: true,
          message: 'Desvío confirmado. Recalculando tu ruta…',
        ),
      );
      await recalculate();
    }
  }

  void arOpened() {
    if (!canOpenAr) return;
    emit(state.copy(mode: GuidanceMode.ar, spatialReferenceReady: false));
  }

  bool get canOpenAr =>
      state.canGuide &&
      state.progress?.fraction != 1 &&
      (state.position?.metersPerUnit ?? 0) > 0;

  void arCalibrated() {
    if (state.mode == GuidanceMode.ar) {
      emit(state.copy(spatialReferenceReady: true));
    }
  }

  void arCalibrationLost() {
    if (state.mode == GuidanceMode.ar) {
      emit(state.copy(spatialReferenceReady: false));
    }
  }

  void returnToMap(String message, {bool fallback = false}) {
    if (state.sessionId.isEmpty) return;
    emit(
      state.copy(
        mode: fallback ? GuidanceMode.fallback : GuidanceMode.map,
        spatialReferenceReady: false,
        message: message,
      ),
    );
  }

  void acceptArProgress(String nodeId, {required bool arrived}) {
    final route = state.route;
    final position = state.position;
    if (state.mode != GuidanceMode.ar ||
        !state.spatialReferenceReady ||
        route == null ||
        position == null) {
      return;
    }
    final index = route.nodes.indexWhere(
      (node) =>
          node.id == nodeId &&
          node.floorId == position.floorId &&
          node.planVersionId == position.planVersionId,
    );
    if (index < 0) return;
    final reached = arrived ? index : index - 1;
    if (reached < (state.progress?.nodeIndex ?? 0)) return;
    final count = route.nodes.length;
    if (arrived && index == count - 1) {
      emit(state.copy(progress: RouteProgress(index, index - 1, 1, false)));
    } else if (reached >= 0 && reached < count - 1) {
      emit(
        state.copy(
          progress: RouteProgress(
            reached,
            reached,
            reached / (count - 1),
            false,
          ),
        ),
      );
    }
  }

  Future<void> recalculate({bool retry = false}) async {
    if (state.target == null ||
        state.position == null ||
        state.quality != LocationQuality.located ||
        state.recalculating) {
      return;
    }
    if (!retry &&
        _lastRouteRequest != null &&
        clock().difference(_lastRouteRequest!) < cooldown) {
      return;
    }
    final request = ++_routeRequest, generation = _generation;
    final origin = state.position!, target = state.target!;
    _lastRouteRequest = clock();
    emit(
      state.copy(
        recalculating: true,
        routeInvalid: true,
        message: 'Calculando una ruta compatible…',
        mode: GuidanceMode.map,
        spatialReferenceReady: false,
      ),
    );
    try {
      final route = await repository.route(target, origin);
      if (isClosed || request != _routeRequest || generation != _generation) {
        return;
      }
      if (state.position?.nodeId != origin.nodeId ||
          state.position?.floorId != origin.floorId ||
          state.position?.planVersionId != origin.planVersionId ||
          route.modelVersionId != state.position?.modelVersionId) {
        emit(
          state.copy(
            recalculating: false,
            routeInvalid: true,
            message: 'El origen cambió. Reintenta con tu ubicación actual.',
          ),
        );
        return;
      }
      if (route.siteId != target.siteId ||
          route.nodes.last.id != target.nodeId) {
        throw const NavigationFailure('La ruta no corresponde al destino.');
      }
      final progress = _tracker.match(route, origin);
      if (progress == null) {
        throw const NavigationFailure(
          'La ruta no corresponde al plano de origen.',
        );
      }
      deviation.reset();
      emit(
        state.copy(
          route: route,
          progress: progress,
          routeInvalid: false,
          recalculating: false,
          message: 'Ruta actualizada. Puedes continuar.',
        ),
      );
    } catch (e) {
      if (!isClosed && generation == _generation && request == _routeRequest) {
        emit(
          state.copy(recalculating: false, routeInvalid: true, message: '$e'),
        );
      }
    }
  }

  bool tracking(Map<Object?, Object?> event) {
    if (isClosed || state.sessionId.isEmpty) return false;
    if (!{
      'normal',
      'recovered',
      'lost',
      'limited',
      'unsupported',
      'permission_denied',
      'closed',
      'error',
    }.contains(event['state'])) {
      return false;
    }
    final time = DateTime.tryParse('${event['timestampUtc']}');
    if (time == null ||
        time.isAfter(clock().add(const Duration(seconds: 2))) ||
        clock().difference(time) > const Duration(seconds: 15) ||
        (_lastArEvent != null && !time.isAfter(_lastArEvent!))) {
      return false;
    }
    _lastArEvent = time;
    final tracking = '${event['state']}';
    if ({
      'lost',
      'limited',
      'unsupported',
      'permission_denied',
      'closed',
      'error',
    }.contains(tracking)) {
      emit(
        state.copy(
          mode: GuidanceMode.fallback,
          spatialReferenceReady: false,
          message: tracking == 'closed'
              ? 'Continúas en el mapa 2D.'
              : 'Referencia AR perdida. Continúa en el mapa 2D.',
        ),
      );
    } else if ({'normal', 'recovered'}.contains(tracking)) {
      // Tracking alone does not align the AR frame with published plan coordinates.
      emit(
        state.copy(
          message:
              'Tracking recuperado. Recalibra la referencia espacial antes de volver a AR.',
        ),
      );
    }
    return true;
  }

  void _fail(Object error) {
    if (!isClosed) {
      emit(
        state.copy(
          quality: LocationQuality.error,
          mode: GuidanceMode.map,
          spatialReferenceReady: false,
          message: '$error',
        ),
      );
    }
  }

  Future<void> stop() async {
    ++_generation;
    ++_routeRequest;
    _timer?.cancel();
    _timer = null;
    await _ble?.cancel();
    _ble = null;
    await scanner.stop();
    filter.clear();
    deviation.reset();
    _lastResolution = null;
    _lastRouteRequest = null;
    _lastArEvent = null;
    if (!isClosed) emit(const IndoorNavigationState());
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }
}
