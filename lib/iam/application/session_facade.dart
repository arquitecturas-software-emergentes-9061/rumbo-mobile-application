import 'package:flutter/foundation.dart';
import '../domain/session.dart';
import '../domain/session_repository.dart';

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class Unauthenticated extends SessionState {
  const Unauthenticated({required this.firstVisit});
  final bool firstVisit;
}

class SessionExpired extends SessionState {
  const SessionExpired(this.email);
  final String email;
}

class Authenticated extends SessionState {
  const Authenticated({required this.profileConfigured});
  final bool profileConfigured;
}

class RetryableError extends SessionState {
  const RetryableError();
}

class SessionFacade extends ChangeNotifier {
  SessionFacade(this.repository);
  final SessionRepository repository;
  SessionState state = const SessionLoading();
  Session? _session;
  String email = '';
  Future<bool>? _refreshing;
  String? get currentAccessToken => _session?.accessToken;
  void _set(SessionState value) {
    state = value;
    notifyListeners();
  }

  void markProfileConfigured() {
    final current = state;
    if (current is Authenticated && !current.profileConfigured) {
      _set(const Authenticated(profileConfigured: true));
    }
  }

  // First visit means no saved session. A rejected refresh is expired;
  // configured=false means a first account visit and routes to /profile.
  // Network/5xx failures retain storage, including any rotated refresh token.
  Future<void> restore() async {
    _set(const SessionLoading());
    try {
      final saved = await repository.read();
      email = saved.email ?? '';
      if (saved.refreshToken == null) {
        _set(Unauthenticated(firstVisit: saved.email == null));
        return;
      }
      if (!await refresh()) return;
      final configured = await repository.profileConfigured(
        currentAccessToken!,
      );
      _set(Authenticated(profileConfigured: configured));
    } catch (_) {
      _set(const RetryableError());
    }
  }

  Future<bool> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<bool> _refresh() async {
    final saved = await repository.read();
    email = saved.email ?? email;
    if (saved.refreshToken == null) {
      await _expire();
      return false;
    }
    try {
      final session = await repository.refresh(saved.refreshToken!);
      await repository.save(session, email);
      _session = session;
      return true;
    } on SessionFailure catch (error) {
      if (error.status != null && error.status! >= 400 && error.status! < 500) {
        await _expire();
        return false;
      }
      _set(const RetryableError());
      rethrow;
    } catch (_) {
      _set(const RetryableError());
      rethrow;
    }
  }

  Future<void> _expire() async {
    _session = null;
    await repository.clearTokens();
    _set(SessionExpired(email));
  }

  Future<void> signIn(String email, String password) async {
    Session session;
    try {
      session = await repository.signIn(email, password);
    } on SessionFailure catch (error) {
      if (error.status == 401) {
        throw const SessionFailure(
          'El correo o la contraseña son incorrectos.',
        );
      }
      rethrow;
    }
    await repository.save(session, email);
    this.email = email;
    _session = session;
    try {
      _set(
        Authenticated(
          profileConfigured: await repository.profileConfigured(
            session.accessToken,
          ),
        ),
      );
    } catch (_) {
      _set(const RetryableError());
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    await repository.signUp(name, email, password);
    await signIn(email, password);
  }

  Future<void> signOut() async {
    final token = currentAccessToken;
    try {
      if (token != null) await repository.signOut(token);
    } finally {
      await repository.clearTokens();
      _session = null;
      _set(const Unauthenticated(firstVisit: false));
    }
  }
}
