class ProfileValidationFailure implements Exception {
  const ProfileValidationFailure({this.fullName, this.phoneNumber});

  final String? fullName;
  final String? phoneNumber;
}
