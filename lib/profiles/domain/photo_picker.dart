import 'dart:typed_data';

enum PhotoSource { gallery, camera }

abstract interface class PhotoPicker {
  Future<PickedPhoto?> pick(PhotoSource source);
}

class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String? get mimeType {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return 'image/png';
    }
    return null;
  }

  String? get validationError {
    if (bytes.length > 5 * 1024 * 1024) {
      return 'La foto debe pesar como máximo 5 MiB.';
    }
    if (mimeType == null) {
      return 'Selecciona una foto JPEG o PNG.';
    }
    return null;
  }
}
