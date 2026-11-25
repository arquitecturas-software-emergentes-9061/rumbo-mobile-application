import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injections.dart';
import '../../../../iam/presentation/session_cubit.dart';
import '../../profile_cubit.dart';
import 'edit_profile_screen.dart';
import 'profile_preferences_panel.dart';
import 'profile_photo.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(serviceLocator())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Perfil y preferencias')),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final session = context.read<SessionCubit>().facade;
            final profile = state is ProfileLoaded ? state.profile : null;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (state is ProfileLoading)
                  const Center(child: CircularProgressIndicator()),
                if (state is ProfileLoadFailed) ...[
                  const Text('No se pudo cargar el perfil.'),
                  TextButton(
                    onPressed: context.read<ProfileCubit>().load,
                    child: const Text('Reintentar'),
                  ),
                ],
                if (state is ProfileLoaded && profile == null)
                  const Text('No encontramos tu perfil.'),
                if (profile != null) ...[
                  ProfilePhoto(
                    name: profile.fullName,
                    imageUrl: profile.imageUrl,
                  ),
                  const SizedBox(height: 16),
                  Text(profile.fullName, textAlign: TextAlign.center),
                  Text(session.email, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () {
                      final cubit = context.read<ProfileCubit>();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BlocProvider.value(
                            value: cubit,
                            child: EditProfileScreen(
                              profile: profile,
                              email: session.email,
                              onSave: cubit.update,
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Editar perfil'),
                  ),
                  if (profile.phoneNumber != null)
                    Text(profile.phoneNumber!, textAlign: TextAlign.center),
                ],
                if (profile != null)
                  ProfilePreferencesPanel(
                    repository: serviceLocator(),
                    onConfigured: session.markProfileConfigured,
                  ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await session.signOut();
                    } catch (_) {
                      // Local sign-out completes even when the API is offline.
                    }
                  },
                  child: const Text('Cerrar sesión'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
