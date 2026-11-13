import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injections.dart';
import '../../../domain/photo_picker.dart';
import '../../profile_cubit.dart';

class ProfilePhoto extends StatefulWidget {
  const ProfilePhoto({required this.name, this.imageUrl, super.key});

  final String name;
  final String? imageUrl;

  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  bool _busy = false;

  Future<void> _change() async {
    setState(() => _busy = true);
    try {
      final state = context.read<ProfileCubit>().state;
      final hasImage =
          state is ProfileLoaded && state.profile?.imageUrl != null;
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in [
                'Galería',
                'Cámara',
                if (hasImage) 'Quitar foto',
              ])
                ListTile(
                  title: Text(option),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'Quitar foto') {
        await context.read<ProfileCubit>().deleteImage();
        return;
      }
      final photo = await serviceLocator<PhotoPicker>().pick(
        choice == 'Cámara' ? PhotoSource.camera : PhotoSource.gallery,
      );
      if (!mounted || photo == null) return;
      final error = photo.validationError;
      if (error != null) throw FormatException(error);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vista previa'),
          content: Image.memory(
            photo.bytes,
            width: 240,
            height: 240,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('No se pudo mostrar la foto.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usar foto'),
            ),
          ],
        ),
      );
      if (mounted && confirmed == true) {
        await context.read<ProfileCubit>().uploadImage(photo);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'No se pudo abrir la foto. Revisa los permisos e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first).toUpperCase())
        .join();
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final loaded = state is ProfileLoaded ? state : null;
        final imageUrl = loaded?.profile?.imageUrl;
        return Column(
          children: [
            CircleAvatar(
              radius: 32,
              foregroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              onForegroundImageError: imageUrl != null ? (_, _) {} : null,
              child: Text(initials),
            ),
            TextButton(
              onPressed: _busy || (loaded?.imageBusy ?? false) ? null : _change,
              child: const Text('Cambiar foto'),
            ),
            if (loaded?.imageBusy ?? false) const CircularProgressIndicator(),
            if (loaded?.imageError != null) Text(loaded!.imageError!),
          ],
        );
      },
    );
  }
}
