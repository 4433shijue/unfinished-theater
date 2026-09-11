import 'dart:typed_data';

class LocalImageFileData {
  const LocalImageFileData({
    required this.name,
    required this.size,
    required this.bytes,
    this.mimeType,
    this.extension,
  });

  final String name;
  final int size;
  final Uint8List bytes;
  final String? mimeType;
  final String? extension;
}
