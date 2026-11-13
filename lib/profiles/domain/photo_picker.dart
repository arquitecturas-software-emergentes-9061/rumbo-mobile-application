import 'dart:typed_data';

enum PhotoSource { gallery, camera }

abstract interface class PhotoPicker {
  Future<PickedPhoto?> pick(PhotoSource source);
}

class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String? get validationError {
    if (bytes.length > 5 * 1024 * 1024) {
      return 'La foto debe pesar como máximo 5 MiB.';
    }
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    final png =
        bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == pngSignature[i]).every((v) => v);
    if (bytes.isEmpty || (!jpeg && !png)) {
      return 'Selecciona una foto JPEG o PNG.';
    }
    return null;
  }
}
