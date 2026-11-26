import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../application/password_recovery_service.dart';
import '../domain/session.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.recovery,
    this.confirm = false,
    this.initialEmail = '',
  });
  final PasswordRecoveryService recovery;
  final bool confirm;
  final String initialEmail;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _done = false;
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _link.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.confirm) {
        await widget.recovery.resetPassword(_link.text, _password.text);
        _link.clear();
        _password.clear();
        _confirmation.clear();
      } else {
        await widget.recovery.requestLink(_email.text);
      }
      if (mounted) setState(() => _done = true);
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is SessionFailure
              ? failure.message
              : 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Volver a iniciar sesión',
        onPressed: _busy ? null : () => context.go('/sign-in'),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.confirm ? 'Nueva contraseña' : 'Recuperar acceso',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_done) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.confirm
                            ? 'Tu contraseña se actualizó. Inicia sesión con la nueva contraseña.'
                            : 'Si el correo está registrado, recibirás instrucciones para recuperar tu cuenta. Revisa también la carpeta de spam.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go(
                        widget.confirm ? '/sign-in' : '/password-reset',
                      ),
                      child: Text(
                        widget.confirm
                            ? 'Iniciar sesión'
                            : 'Ya tengo un enlace',
                      ),
                    ),
                    if (!widget.confirm)
                      TextButton(
                        onPressed: () => setState(() => _done = false),
                        child: const Text('Solicitar otro enlace'),
                      ),
                  ] else ...[
                    Text(
                      widget.confirm
                          ? 'Pega el enlace recibido por correo y elige una contraseña. El enlace funciona una sola vez.'
                          : 'Ingresa el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    if (!widget.confirm)
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        validator: (value) =>
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Ingresa un correo válido.',
                      ),
                    if (widget.confirm) ...[
                      TextFormField(
                        controller: _link,
                        enabled: !_busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Enlace de recuperación',
                        ),
                        validator: (value) =>
                            PasswordRecoveryService.tokenFromLink(
                                  value ?? '',
                                ) ==
                                null
                            ? 'Pega el enlace completo que recibiste por correo.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_visible,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          helperText:
                              'De 8 a 72 caracteres, 1 mayúscula y 1 número.',
                          helperMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: _visible
                                ? 'Ocultar contraseña'
                                : 'Ver contraseña',
                            onPressed: () =>
                                setState(() => _visible = !_visible),
                            icon: Icon(
                              _visible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value != null &&
                                value.length >= 8 &&
                                value.length <= 72 &&
                                RegExp('[A-Z]').hasMatch(value) &&
                                RegExp('[0-9]').hasMatch(value)
                            ? null
                            : 'Usa de 8 a 72 caracteres, 1 mayúscula y 1 número.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        enabled: !_busy,
                        obscureText: !_visible,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                        ),
                        validator: (value) =>
                            value == _password.text &&
                                (value?.isNotEmpty ?? false)
                            ? null
                            : 'Las contraseñas no coinciden.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Espera…'
                            : widget.confirm
                            ? 'Guardar nueva contraseña'
                            : 'Enviar instrucciones',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.go(
                              widget.confirm
                                  ? '/password-recovery'
                                  : '/password-reset',
                            ),
                      child: Text(
                        widget.confirm
                            ? 'Solicitar otro enlace'
                            : 'Ya tengo un enlace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
