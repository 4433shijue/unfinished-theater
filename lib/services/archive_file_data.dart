import 'dart:typed_data';

const int maxArchiveImportBytes = 64 * 1024 * 1024;

class ArchiveFileSelectionException implements Exception {
  const ArchiveFileSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

void validateArchiveFileMetadata({
  required String name,
  required int size,
  required List<String> allowedExtensions,
  int maxBytes = maxArchiveImportBytes,
}) {
  final normalizedName = name.trim().toLowerCase();
  final normalizedExtensions = allowedExtensions
      .map((extension) => extension.trim().toLowerCase().replaceFirst('.', ''))
      .where((extension) => extension.isNotEmpty)
      .toSet();
  final separator = normalizedName.lastIndexOf('.');
  final extension =
      separator < 0 ? '' : normalizedName.substring(separator + 1);
  if (normalizedExtensions.isNotEmpty &&
      !normalizedExtensions.contains(extension)) {
    throw ArchiveFileSelectionException(
      '不支持 .$extension 文件，请选择 ${normalizedExtensions.map((item) => '.$item').join('、')}。',
    );
  }
  if (size > maxBytes) {
    throw ArchiveFileSelectionException(
      '文件大小超过 ${_formatMegabytes(maxBytes)}MB 上限。',
    );
  }
}

String _formatMegabytes(int bytes) {
  final megabytes = bytes / (1024 * 1024);
  return megabytes == megabytes.roundToDouble()
      ? megabytes.toInt().toString()
      : megabytes.toStringAsFixed(1);
}

class ArchiveFileData {
  const ArchiveFileData({
    required this.name,
    required this.size,
    required this.bytes,
  });

  final String name;
  final int size;
  final Uint8List bytes;
}
