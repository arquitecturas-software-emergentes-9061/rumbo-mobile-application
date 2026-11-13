import 'package:flutter/material.dart';

import '../../../../injections.dart';
import '../../../domain/photo_picker.dart';

/// A local photo draft. Uploading and deleting server images belong to PR-61.
class ProfilePhoto extends StatefulWidget {
  const ProfilePhoto({required this.name, this.imageUrl, super.key});

  final String name;
  final String? imageUrl;

  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  PickedPhoto? _draft;
  bool _removed = false;
  bool _busy = false;

  Future<void> _change() async {
    setState(() => _busy = true);
    try {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in [
                'Galería',
                'Cámara',
                if (_draft != null || (!_removed && widget.imageUrl != null))
                  'Quitar foto',
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
        setState(() {
          _draft = null;
          _removed = true;
        });
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
        setState(() {
          _draft = photo;
          _removed = false;
        });
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
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          foregroundImage: _draft != null
              ? MemoryImage(_draft!.bytes)
              : (!_removed && widget.imageUrl != null
                    ? NetworkImage(widget.imageUrl!)
                    : null),
          child: Text(initials),
        ),
        TextButton(
          onPressed: _busy ? null : _change,
          child: const Text('Cambiar foto'),
        ),
      ],
    );
  }
}
