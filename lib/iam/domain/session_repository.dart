import 'session.dart';

abstract interface class SessionRepository {
  Future<StoredSession> read();
  Future<void> save(Session session, String email);
  Future<void> clearTokens();
  Future<Session> signIn(String email, String password);
  Future<void> signUp(String name, String email, String password);
  Future<Session> refresh(String token);
  Future<bool> profileConfigured(String accessToken);
  Future<void> signOut(String accessToken);
}
