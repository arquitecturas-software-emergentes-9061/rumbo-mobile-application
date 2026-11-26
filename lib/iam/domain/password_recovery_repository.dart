abstract interface class PasswordRecoveryRepository {
  Future<void> requestLink(String email);
  Future<void> resetPassword(String token, String newPassword);
}
