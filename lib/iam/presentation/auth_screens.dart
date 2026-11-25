import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../application/session_facade.dart';
import '../domain/session.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_outlined, size: 80),
              const Text(
                'Rumbo',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Text(
                'Encuentra tu camino dentro de la clínica',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Iniciar sesión'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/sign-up'),
                child: const Text('Crear cuenta'),
              ),
              const SizedBox(height: 24),
              const Text('EN / ES', semanticsLabel: 'Idioma actual: español'),
            ],
          ),
        ),
      ),
    ),
  );
}

class SessionGateScreen extends StatelessWidget {
  const SessionGateScreen({required this.session, super.key});
  final SessionFacade session;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: session.state is RetryableError
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo recuperar tu sesión. Inténtalo de nuevo.',
                ),
                FilledButton(
                  onPressed: session.restore,
                  child: const Text('Reintentar'),
                ),
              ],
            )
          : const CircularProgressIndicator(),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.session, this.signUp = false, super.key});
  final SessionFacade session;
  final bool signUp;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  // Only sign-in reuses the last email; a new registration always starts empty.
  late final _email = TextEditingController(
    text: widget.signUp ? '' : widget.session.email,
  );
  final _password = TextEditingController();
  bool _visible = false;
  bool _terms = false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.signUp) {
        await widget.session.signUp(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } else {
        await widget.session.signIn(_email.text.trim(), _password.text);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is SessionFailure
              ? error.message
              : 'No se pudo conectar. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registering = widget.signUp;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 110,
        leading: TextButton(
          onPressed: _busy ? null : () => context.go('/welcome'),
          child: const Text('← Volver'),
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
                      registering ? 'Crear cuenta' : 'Iniciar sesión',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Bienvenido a Rumbo'),
                    const SizedBox(height: 24),
                    if (!registering && widget.session.state is SessionExpired)
                      const _ErrorBox(
                        'Tu sesión expiró. Inicia sesión de nuevo.',
                      ),
                    if (_error != null) _ErrorBox(_error!),
                    if (registering)
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo *',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa tu nombre completo.'
                            : null,
                      ),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico *',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa tu correo electrónico.';
                        }
                        return RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                            ? null
                            : 'Ingresa un correo válido.';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: !_visible,
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        helperText: registering
                            ? 'Mín. 8 caracteres, 1 mayúscula, 1 número'
                            : null,
                        suffixIcon: IconButton(
                          tooltip: _visible
                              ? 'Ocultar contraseña'
                              : 'Ver contraseña',
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa tu contraseña.';
                        }
                        if (registering &&
                            (v.length < 8 ||
                                !RegExp('[A-Z]').hasMatch(v) ||
                                !RegExp('[0-9]').hasMatch(v))) {
                          return 'Usa 8 caracteres, 1 mayúscula y 1 número.';
                        }
                        return null;
                      },
                    ),
                    if (registering)
                      FormField<bool>(
                        initialValue: false,
                        validator: (_) => _terms
                            ? null
                            : 'Debes aceptar los términos y la política de privacidad.',
                        builder: (field) => Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _terms,
                              title: const Text(
                                'Acepto los Términos de Servicio y la Política de Privacidad',
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      setState(() => _terms = value ?? false);
                                      field.didChange(_terms);
                                    },
                            ),
                            if (field.hasError)
                              Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (!registering)
                      TextButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Contacta a soporte para recuperar tu contraseña.',
                            ),
                          ),
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Espera…'
                            : registering
                            ? 'CREAR CUENTA →'
                            : 'Iniciar sesión',
                      ),
                    ),
                    if (registering)
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/sign-in'),
                        child: const Text('¿Ya te registraste? Iniciar sesión'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
