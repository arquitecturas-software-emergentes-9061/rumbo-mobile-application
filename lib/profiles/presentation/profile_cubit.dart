import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/profile.dart';
import '../infrastructure/profile_repository.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);
  final Profile? profile;
}

class ProfileLoadFailed extends ProfileState {
  const ProfileLoadFailed();
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this.repository) : super(const ProfileLoading());
  final ProfileRepository repository;

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
