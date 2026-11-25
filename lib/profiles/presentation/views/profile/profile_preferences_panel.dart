import 'package:flutter/material.dart';
import '../../../domain/route_preferences.dart';
import '../../../infrastructure/profile_repository.dart';
import 'route_preference_controls.dart';

class ProfilePreferencesPanel extends StatefulWidget {
  const ProfilePreferencesPanel({required this.repository, super.key});

  final ProfileRepository repository;

  @override
  State<ProfilePreferencesPanel> createState() =>
      _ProfilePreferencesPanelState();
}

class _ProfilePreferencesPanelState extends State<ProfilePreferencesPanel> {
  RoutePreferences? _value;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([RoutePreferences? change]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await (change == null
          ? widget.repository.preferences()
          : widget.repository.savePreferences(change));
      if (mounted) setState(() => _value = value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron actualizar las preferencias.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (value == null && !_busy)
          TextButton(onPressed: () => _load(), child: const Text('Reintentar')),
        if (value != null) ...[
          if (!value.configured)
            const Text('Configura tus preferencias de ruta.'),
          RoutePreferenceControls(
            avoidStairs: value.avoidStairs,
            simplerRoute: value.simplerRoute,
            voiceGuidance: value.voiceGuidance,
            onAvoidStairsChanged: _busy
                ? null
                : (v) => _load(value.copyWith(avoidStairs: v)),
            onSimplerRouteChanged: _busy
                ? null
                : (v) => _load(value.copyWith(simplerRoute: v)),
            onVoiceGuidanceChanged: _busy
                ? null
                : (v) => _load(value.copyWith(voiceGuidance: v)),
          ),
        ],
      ],
    );
  }
}
