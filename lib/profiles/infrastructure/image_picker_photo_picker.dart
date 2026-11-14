import 'package:image_picker/image_picker.dart';

import '../domain/photo_picker.dart';

class ImagePickerPhotoPicker implements PhotoPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('La foto debe pesar como máximo 5 MiB.');
    }
    return PickedPhoto(name: file.name, bytes: await file.readAsBytes());
  }
}
