import 'package:flutter/material.dart';
import '../../../domain/profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.profile,
    required this.email,
    required this.onSave,
    super.key,
  });

  final Profile profile;
  final String email;
  final Future<void> Function(String, String?) onSave;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim();
      await widget.onSave(_name.text.trim(), phone.isEmpty ? null : phone);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudieron guardar los cambios. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              readOnly: _saving,
              decoration: const InputDecoration(labelText: 'Nombre completo *'),
              validator: (input) {
                final value = input?.trim() ?? '';
                if (value.isEmpty) return 'Ingresa tu nombre completo.';
                if (value.length > 255) {
                  return 'Usa como máximo 255 caracteres.';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _phone,
              readOnly: _saving,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                helperText: 'Número móvil con código de país',
              ),
              validator: (input) {
                final value = input?.trim() ?? '';
                if (value.isEmpty) return null;
                if (value.length > 30 ||
                    !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(value) ||
                    !RegExp(r'[0-9]').hasMatch(value)) {
                  return 'Ingresa un número de teléfono válido.';
                }
                return null;
              },
            ),
            TextFormField(
              initialValue: widget.email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                helperText:
                    'Identificador de tu cuenta. Contacta a soporte para cambiarlo.',
                helperMaxLines: 2,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
