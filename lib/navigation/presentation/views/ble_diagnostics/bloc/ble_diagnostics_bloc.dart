import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rumbo_mobile_application/navigation/application/ble_diagnostics_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_observation.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_event.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_state.dart';

class BleDiagnosticsBloc
    extends Bloc<BleDiagnosticsEvent, BleDiagnosticsState> {
  BleDiagnosticsBloc({required this.bleDiagnosticsFacadeService})
    : super(const BleDiagnosticsState()) {
    on<BleDiagnosticsStarted>(_onRefreshed);
    on<BleDiagnosticsRefreshed>(_onRefreshed);
    on<BleDiscoveryRequested>(_onDiscoveryRequested);
    on<BleCaptureRequested>(_onCaptureRequested);
    on<BleScanStopRequested>(_onStopRequested);
    on<BleSettingsRequested>(_onSettingsRequested);
    on<BlePlatformEventReceived>(_onPlatformEvent);
    on<BlePlatformErrorReceived>(_onPlatformError);
    _subscription = bleDiagnosticsFacadeService.events.listen(
      (event) => add(BlePlatformEventReceived(event)),
      onError: (Object error) => add(BlePlatformErrorReceived(error)),
    );
  }

  final BleDiagnosticsFacadeService<AndroidBleSessionConfiguration>
  bleDiagnosticsFacadeService;
  late final StreamSubscription<BleScanEvent> _subscription;
  final Map<String, BleObservation> _latest = {};
  bool _starting = false;

  Future<void> _onRefreshed(
    BleDiagnosticsEvent event,
    Emitter<BleDiagnosticsState> emit,
  ) async {
    try {
      final snapshot = await bleDiagnosticsFacadeService.snapshot();
      if (emit.isDone || _starting) return;
      emit(
        state.copyWith(
          status: snapshot.status,
          message: snapshot.message,
          savedCount: snapshot.savedCount,
          filePath: snapshot.filePath,
        ),
      );
    } catch (error) {
      if (!emit.isDone) _showError(error, emit);
    }
  }

  Future<void> _onDiscoveryRequested(
    BleDiscoveryRequested event,
    Emitter<BleDiagnosticsState> emit,
  ) async {
    if (_starting || state.busy || state.isActive) return;
    _starting = true;
    emit(
      state.copyWith(
        busy: true,
        status: 'starting',
        message: 'Solicitando acceso BLE...',
      ),
    );
    try {
      final granted = await bleDiagnosticsFacadeService.discover();
      if (emit.isDone) return;
      if (!granted) {
        emit(
          state.copyWith(
            busy: false,
            status: 'permissionsDenied',
            message:
                'Autoriza Bluetooth y ubicación precisa para detectar balizas.',
          ),
        );
        return;
      }
      _latest.clear();
      emit(
        state.copyWith(
          busy: false,
          status: state.status == 'starting' ? 'discovering' : state.status,
          observations: const [],
        ),
      );
    } catch (error) {
      if (!emit.isDone) _showError(error, emit);
    } finally {
      _starting = false;
    }
  }

  Future<void> _onCaptureRequested(
    BleCaptureRequested event,
    Emitter<BleDiagnosticsState> emit,
  ) async {
    if (_starting || state.busy || state.isActive) return;
    _starting = true;
    emit(
      state.copyWith(
        busy: true,
        status: 'starting',
        message: 'Solicitando acceso BLE...',
      ),
    );
    try {
      final granted = await bleDiagnosticsFacadeService.startCapture(
        event.configuration,
      );
      if (emit.isDone) return;
      if (!granted) {
        emit(
          state.copyWith(
            busy: false,
            status: 'permissionsDenied',
            message:
                'Autoriza Bluetooth y ubicación precisa para capturar RSSI.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          busy: false,
          status: state.status == 'starting' ? 'scanning' : state.status,
        ),
      );
    } catch (error) {
      if (!emit.isDone) _showError(error, emit);
    } finally {
      _starting = false;
    }
  }

  Future<void> _onStopRequested(
    BleScanStopRequested event,
    Emitter<BleDiagnosticsState> emit,
  ) async {
    if (state.busy || _starting) return;
    emit(state.copyWith(busy: true));
    try {
      await bleDiagnosticsFacadeService.stop();
      final snapshot = await bleDiagnosticsFacadeService.snapshot();
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: snapshot.status,
          message: snapshot.message,
          savedCount: snapshot.savedCount,
          filePath: snapshot.filePath,
          busy: false,
        ),
      );
    } catch (error) {
      if (!emit.isDone) _showError(error, emit);
    }
  }

  Future<void> _onSettingsRequested(
    BleSettingsRequested event,
    Emitter<BleDiagnosticsState> emit,
  ) async {
    try {
      await bleDiagnosticsFacadeService.openSettings();
    } catch (error) {
      if (!emit.isDone) _showError(error, emit);
    }
  }

  void _onPlatformEvent(
    BlePlatformEventReceived event,
    Emitter<BleDiagnosticsState> emit,
  ) {
    switch (event.event) {
      case BleObservationReceived(:final observation):
        _latest[observation.deviceId] = observation;
        if (_latest.length > 100) {
          final oldest = _latest.values.reduce(
            (a, b) => a.observedAt.isBefore(b.observedAt) ? a : b,
          );
          _latest.remove(oldest.deviceId);
        }
        final observations = _latest.values.toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
        emit(state.copyWith(observations: List.unmodifiable(observations)));
      case BleScanStatusChanged(:final status, :final message):
        emit(state.copyWith(status: status, message: message, busy: false));
      case BleSampleSaved(:final total):
        emit(state.copyWith(savedCount: total));
    }
  }

  void _onPlatformError(
    BlePlatformErrorReceived event,
    Emitter<BleDiagnosticsState> emit,
  ) => _showError(event.error, emit);

  void _showError(Object error, Emitter<BleDiagnosticsState> emit) {
    emit(state.copyWith(status: 'error', message: '$error', busy: false));
  }

  @override
  Future<void> close() async {
    // Closing diagnostics must leave the Android foreground capture running.
    await _subscription.cancel();
    await super.close();
  }
}
