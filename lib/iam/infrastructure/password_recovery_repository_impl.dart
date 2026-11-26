import '../domain/password_recovery_repository.dart';
import '../domain/session.dart';
import 'auth_api.dart';

/// Uses the public IAM endpoints, without access tokens or session refresh.
class PasswordRecoveryRepositoryImpl implements PasswordRecoveryRepository {
  PasswordRecoveryRepositoryImpl(this.api);
  final AuthApi api;

  @override
  Future<void> requestLink(String email) async {
    await api.request('password-recovery/requests', body: {'email': email});
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await api.request(
        'password-recovery/confirmations',
        body: {'resetToken': token, 'newPassword': newPassword},
      );
    } on SessionFailure catch (failure) {
      if (failure.status == 400) {
        throw const SessionFailure(
          'El enlace no es válido, venció o ya fue usado. Solicita uno nuevo.',
          status: 400,
        );
      }
      rethrow;
    }
  }
}
