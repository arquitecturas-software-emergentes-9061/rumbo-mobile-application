import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_bloc.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_event.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_state.dart';

/// Developer-only capture tool, intentionally separate from the product UI.
class BleDiagnosticsScreen extends StatefulWidget {
  const BleDiagnosticsScreen({super.key});

  @override
  State<BleDiagnosticsScreen> createState() => _BleDiagnosticsScreenState();
}

class _BleDiagnosticsScreenState extends State<BleDiagnosticsScreen>
    with WidgetsBindingObserver {
  final _location = TextEditingController();
  final _condition = TextEditingController();
  final _serviceUuids = TextEditingController();
  final Set<String> _selectedAddresses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<BleDiagnosticsBloc>().add(const BleDiagnosticsRefreshed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _location.dispose();
    _condition.dispose();
    _serviceUuids.dispose();
    super.dispose();
  }

  void _startCapture() {
    try {
      final config = AndroidBleSessionConfiguration(
        referenceLocation: _location.text,
        condition: _condition.text,
        deviceAddresses: _selectedAddresses,
        serviceUuids: _serviceUuids.text.split(','),
      );
      context.read<BleDiagnosticsBloc>().add(BleCaptureRequested(config));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico BLE')),
      body: BlocBuilder<BleDiagnosticsBloc, BleDiagnosticsState>(
        builder: (context, state) {
          final bloc = context.read<BleDiagnosticsBloc>();
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Herramienta de desarrollo: no es una pantalla final. '
                  'RSSI no equivale directamente a distancia.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _location,
                  enabled: !state.isActive,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación de referencia',
                    hintText: 'Ej. Piso 1, recepción, punto A',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _condition,
                  enabled: !state.isActive,
                  decoration: const InputDecoration(
                    labelText: 'Condición de recorrido',
                    hintText: 'Ej. quieta, caminando, puerta abierta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceUuids,
                  enabled: !state.isActive,
                  decoration: const InputDecoration(
                    labelText: 'UUID de servicio BLE (opcional)',
                    hintText: 'Separar varios UUID con comas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: state.busy || state.isActive
                          ? null
                          : () => bloc.add(const BleDiscoveryRequested()),
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Descubrir 10 s'),
                    ),
                    FilledButton.icon(
                      onPressed: state.busy || state.isActive
                          ? null
                          : _startCapture,
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Capturar RSSI'),
                    ),
                    if (state.isActive)
                      OutlinedButton.icon(
                        onPressed: state.busy
                            ? null
                            : () => bloc.add(const BleScanStopRequested()),
                        icon: const Icon(Icons.stop),
                        label: const Text('Detener'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Estado: ${_statusLabel(state.status)}'),
                if (state.message.isNotEmpty) Text(state.message),
                if (state.status == 'permissionsDenied')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => bloc.add(const BleSettingsRequested()),
                      child: const Text('Abrir ajustes de la app'),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Mediciones guardadas: ${state.savedCount}'),
                if (state.filePath.isNotEmpty)
                  SelectableText('CSV privado: ${state.filePath}'),
                if (state.savedCount > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: state.busy || state.isActive
                          ? null
                          : () => bloc.add(const BleCsvExportRequested()),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Exportar CSV RSSI'),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Balizas detectadas (${state.observations.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Descubre con la pantalla encendida y selecciona las balizas. '
                  'La captura filtrada puede continuar al minimizar o bloquear.',
                ),
                if (state.observations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Todavía no hay dispositivos detectados.'),
                  ),
                ...state.observations.take(40).map((observation) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _selectedAddresses.contains(observation.deviceId),
                    onChanged: state.isActive
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedAddresses.add(observation.deviceId);
                              } else {
                                _selectedAddresses.remove(observation.deviceId);
                              }
                            });
                          },
                    title: Text(
                      observation.name.isEmpty
                          ? observation.deviceId
                          : '${observation.name} · ${observation.deviceId}',
                    ),
                    subtitle: Text(
                      '${observation.rssi} dBm · ${observation.observedAt.toLocal()}',
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'idle' => 'Inactivo',
    'starting' => 'Iniciando',
    'discovering' => 'Descubriendo dispositivos',
    'scanning' => 'Escaneando',
    'paused' => 'Pausa del ciclo',
    'empty' => 'Sin balizas en esta ventana',
    'noDevices' => 'No se detectaron balizas',
    'bluetoothOff' => 'Bluetooth apagado',
    'permissionsDenied' => 'Permisos denegados',
    'locationOff' => 'Ubicación del dispositivo apagada',
    'unsupported' => 'BLE no disponible',
    'error' => 'Error',
    _ => status,
  };
}
