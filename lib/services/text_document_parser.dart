import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class TextDocumentParser {
  const TextDocumentParser._();

  static String parse({
    required String fileName,
    required Uint8List bytes,
  }) {
    final extension = _extension(fileName);
    return switch (extension) {
      'docx' => _parseDocx(bytes),
      'json' || 'md' || 'txt' || 'doc' => _decodeText(bytes),
      _ => _decodeText(bytes),
    };
  }

  static String _parseDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final document = archive.files.firstWhere(
        (file) => file.name == 'word/document.xml',
        orElse: () =>
            throw const FormatException('Word document body not found.'),
      );
      final raw =
          utf8.decode(document.content as List<int>, allowMalformed: true);
      final paragraphs = RegExp(
        r'<w:p[\s\S]*?</w:p>',
        caseSensitive: false,
      ).allMatches(raw).map((match) {
        final paragraph = match.group(0) ?? '';
        final texts = RegExp(
          r'<w:t[^>]*>([\s\S]*?)</w:t>',
          caseSensitive: false,
        )
            .allMatches(paragraph)
            .map((textMatch) => _xmlUnescape(textMatch.group(1) ?? ''))
            .join();
        return texts.trim();
      }).where((line) => line.isNotEmpty);
      final parsed = paragraphs.join('\n').trim();
      return parsed.isEmpty ? _decodeText(bytes) : parsed;
    } catch (_) {
      return _decodeText(bytes);
    }
  }

  static String _decodeText(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    final cleaned = utf8Text
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .trim();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return latin1.decode(bytes, allowInvalid: true).trim();
  }

  static String _xmlUnescape(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static String _extension(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final index = normalized.lastIndexOf('.');
    if (index == -1 || index == normalized.length - 1) {
      return '';
    }
    return normalized.substring(index + 1);
  }
}
