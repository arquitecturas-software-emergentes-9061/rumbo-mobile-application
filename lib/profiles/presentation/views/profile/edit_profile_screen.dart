import 'package:flutter/material.dart';
import '../../../domain/profile.dart';
import '../../../domain/profile_validation_failure.dart';
import 'profile_photo.dart';

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
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _nameError = null;
      _phoneError = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim();
      await widget.onSave(_name.text.trim(), phone.isEmpty ? null : phone);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (error is ProfileValidationFailure) {
          _nameError = error.fullName;
          _phoneError = error.phoneNumber;
        } else {
          _error = 'No se pudieron guardar los cambios. Inténtalo de nuevo.';
        }
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
            ProfilePhoto(
              name: widget.profile.fullName,
              imageUrl: widget.profile.imageUrl,
            ),
            TextFormField(
              controller: _name,
              readOnly: _saving,
              onChanged: (_) => setState(() => _nameError = null),
              decoration: InputDecoration(
                labelText: 'Nombre completo *',
                errorText: _nameError,
              ),
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
              onChanged: (_) => setState(() => _phoneError = null),
              decoration: InputDecoration(
                labelText: 'Teléfono',
                errorText: _phoneError,
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
