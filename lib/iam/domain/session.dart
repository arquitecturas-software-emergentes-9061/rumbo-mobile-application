class Session {
  const Session({
    required this.userId,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });
  final String userId;
  final String role;
  final String accessToken;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
}

class StoredSession {
  const StoredSession({this.refreshToken, this.email, this.userId});
  final String? refreshToken;
  final String? email;
  final String? userId;
}

class SessionFailure implements Exception {
  const SessionFailure(this.message, {this.status});
  final String message;
  final int? status;
}
