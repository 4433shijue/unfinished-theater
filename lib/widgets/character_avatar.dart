import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.name,
    this.avatarDataUri = '',
    this.selected = false,
    this.large = false,
    this.size,
  });

  final String name;
  final String avatarDataUri;
  final bool selected;
  final bool large;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (large ? 76.0 : 58.0);
    final radius = large ? 24.0 : 20.0;
    final imageBytes = _decodeAvatarDataUri(avatarDataUri);

    return Container(
      width: resolvedSize,
      height: resolvedSize,
      decoration: BoxDecoration(
        gradient: imageBytes == null ? AppTheme.brandGradient : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppTheme.isLightPaletteMode
              ? AppTheme.activePrimary.withValues(alpha: selected ? 0.34 : 0.2)
              : Colors.white.withValues(alpha: selected ? 0.34 : 0.2),
        ),
        boxShadow: selected ? AppTheme.neonGlow(alpha: 0.08) : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageBytes == null
          ? Text(
              _initialsOf(name),
              style: TextStyle(
                color: AppTheme.selectedTintText,
                fontWeight: FontWeight.w900,
                fontSize: large ? 28 : 22,
              ),
            )
          : Image.memory(
              imageBytes,
              width: resolvedSize,
              height: resolvedSize,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '未';
  }
  return trimmed.substring(0, 1);
}

Uint8List? _decodeAvatarDataUri(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('data:image/')) {
    return null;
  }
  final commaIndex = trimmed.indexOf(',');
  if (commaIndex == -1 || commaIndex >= trimmed.length - 1) {
    return null;
  }
  try {
    return base64Decode(trimmed.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
