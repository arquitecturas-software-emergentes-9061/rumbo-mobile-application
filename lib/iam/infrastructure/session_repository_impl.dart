import '../domain/session.dart';
import '../domain/session_repository.dart';
import 'auth_api.dart';
import 'secure_session_storage.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this.api, this.storage);
  final AuthApi api;
  final SecureSessionStorage storage;
  @override
  Future<StoredSession> read() => storage.read();
  @override
  Future<void> save(Session session, String email) =>
      storage.save(session, email);
  @override
  Future<void> clearTokens() => storage.clearTokens();
  @override
  Future<Session> signIn(String email, String password) =>
      api.authenticate('sign-in', {'email': email, 'password': password});
  @override
  Future<void> signUp(String name, String email, String password) async {
    await api.request(
      'auth/sign-up',
      body: {
        'fullName': name,
        'email': email,
        'password': password,
        'role': 'PATIENT',
        'acceptedTerms': true,
      },
    );
  }

  @override
  Future<Session> refresh(String token) =>
      api.authenticate('refresh', {'refreshToken': token});
  @override
  Future<bool> profileConfigured(String accessToken) async {
    final data = await api.request(
      'profiles/me/preferences',
      token: accessToken,
      get: true,
    );
    if (data['configured'] is! bool) {
      throw const SessionFailure('No se pudieron cargar las preferencias.');
    }
    return data['configured'] as bool;
  }

  @override
  Future<void> signOut(String accessToken) async {
    await api.request('auth/sign-out', token: accessToken);
  }
}
