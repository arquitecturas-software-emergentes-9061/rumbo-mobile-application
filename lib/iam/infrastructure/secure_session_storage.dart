import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/session.dart';

class SecureSessionStorage {
  SecureSessionStorage(this.storage);
  final FlutterSecureStorage storage;
  static const key = 'rumbo.visitor.session';

  Future<StoredSession> read() async {
    final value = await storage.read(key: key);
    if (value == null) return const StoredSession();
    final data = jsonDecode(value) as Map<String, dynamic>;
    return StoredSession(
      refreshToken: data['refreshToken'] as String?,
      email: data['email'] as String?,
      userId: data['userId'] as String?,
    );
  }

  // One secure write persists the rotated refresh token atomically. Access
  // tokens live only in memory and must never be persisted or logged.
  Future<void> save(Session session, String email) => storage.write(
    key: key,
    value: jsonEncode({
      'refreshToken': session.refreshToken,
      'email': email,
      'userId': session.userId,
    }),
  );

  Future<void> clearTokens() async {
    final saved = await read();
    await storage.write(
      key: key,
      value: jsonEncode({'email': saved.email, 'userId': saved.userId}),
    );
  }
}
