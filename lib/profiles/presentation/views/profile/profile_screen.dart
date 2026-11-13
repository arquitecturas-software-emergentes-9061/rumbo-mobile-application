import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../iam/presentation/session_cubit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil y preferencias')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.person_outline, size: 64),
            const Text(
              'Aquí se incorporarán los datos y las preferencias de guiado del visitante.',
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                try {
                  await context.read<SessionCubit>().facade.signOut();
                } catch (_) {
                  /* Local sign-out completes even when the API is offline. */
                }
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
