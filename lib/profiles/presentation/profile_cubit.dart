import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/profile.dart';
import '../domain/photo_picker.dart';
import '../infrastructure/profile_repository.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile, {this.imageBusy = false, this.imageError});
  final Profile? profile;
  final bool imageBusy;
  final String? imageError;
}

class ProfileLoadFailed extends ProfileState {
  const ProfileLoadFailed();
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this.repository) : super(const ProfileLoading());
  final ProfileRepository repository;

  Future<void> uploadImage(PickedPhoto photo) =>
      _changeImage(() => repository.uploadImage(photo));
  Future<void> deleteImage() => _changeImage(repository.deleteImage);

  Future<void> _changeImage(Future<Profile> Function() operation) async {
    final previous = state;
    if (previous is! ProfileLoaded || previous.imageBusy) return;
    emit(ProfileLoaded(previous.profile, imageBusy: true));
    try {
      final profile = await operation();
      if (!isClosed) emit(ProfileLoaded(profile));
    } catch (error) {
      if (!isClosed) {
        emit(
          ProfileLoaded(
            previous.profile,
            imageError: error is ProfileImageFailure
                ? error.message
                : 'No se pudo actualizar la foto. Revisa tu conexión e inténtalo de nuevo.',
          ),
        );
      }
    }
  }

  Future<void> update(String fullName, String? phoneNumber) async {
    final profile = await repository.update(fullName, phoneNumber);
    if (!isClosed) emit(ProfileLoaded(profile));
  }

  Future<void> load() async {
    emit(const ProfileLoading());
    try {
      final profile = await repository.load();
      if (!isClosed) emit(ProfileLoaded(profile));
    } catch (_) {
      if (!isClosed) emit(const ProfileLoadFailed());
    }
  }
}
