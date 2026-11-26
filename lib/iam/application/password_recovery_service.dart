import '../domain/password_recovery_repository.dart';
import '../domain/session.dart';

/// Recovery secrets live only in the form and the HTTP request; never in session storage.
class PasswordRecoveryService {
  PasswordRecoveryService(this.repository);
  final PasswordRecoveryRepository repository;

  static String? tokenFromLink(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    final String token;
    if (uri != null && uri.hasScheme) {
      if (!['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
        return null;
      }
      final tokens = uri.queryParametersAll['token'];
      if (tokens == null || tokens.length != 1) return null;
      token = tokens.single;
    } else {
      token = input;
    }
    return RegExp(r'^[A-Za-z0-9_-]{20,512}$').hasMatch(token) ? token : null;
  }

  Future<void> requestLink(String email) =>
      repository.requestLink(email.trim());

  Future<void> resetPassword(String link, String newPassword) async {
    final token = tokenFromLink(link);
    if (token == null) {
      throw const SessionFailure(
        'Pega el enlace completo que recibiste por correo.',
      );
    }
    await repository.resetPassword(token, newPassword);
  }
}
