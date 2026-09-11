import '../utils/id_generator.dart';

enum MusicLoopMode {
  playlist,
  single,
}

class BackgroundTrack {
  const BackgroundTrack({
    required this.id,
    required this.title,
    required this.originalName,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
    required this.storageKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackgroundTrack.create({
    required String originalName,
    required String mimeType,
    required String extension,
    required int sizeBytes,
    required String storageKey,
    String? title,
  }) {
    final now = DateTime.now();
    final fallbackTitle = _titleFromFileName(originalName);
    return BackgroundTrack(
      id: IdGenerator.generic('audio'),
      title: _cleanTitle(title).isEmpty ? fallbackTitle : _cleanTitle(title),
      originalName: originalName.trim(),
      mimeType: mimeType.trim(),
      extension: extension.trim().toLowerCase(),
      sizeBytes: sizeBytes,
      storageKey: storageKey.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory BackgroundTrack.fromJson(Map<String, dynamic> json) {
    final originalName = json['originalName']?.toString() ?? '';
    final title = _cleanTitle(json['title']?.toString());
    return BackgroundTrack(
      id: json['id']?.toString() ?? '',
      title: title.isEmpty ? _titleFromFileName(originalName) : title,
      originalName: originalName,
      mimeType: json['mimeType']?.toString() ?? '',
      extension: json['extension']?.toString() ?? '',
      sizeBytes: _readInt(json['sizeBytes']),
      storageKey: json['storageKey']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String originalName;
  final String mimeType;
  final String extension;
  final int sizeBytes;
  final String storageKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayFormat {
    if (extension.trim().isNotEmpty) {
      return extension.trim().toUpperCase();
    }
    if (mimeType.trim().isNotEmpty) {
      return mimeType.trim();
    }
    return 'AUDIO';
  }

  BackgroundTrack rename(String nextTitle) {
    final clean = _cleanTitle(nextTitle);
    if (clean.isEmpty || clean == title) {
      return this;
    }
    return copyWith(title: clean, updatedAt: DateTime.now());
  }

  BackgroundTrack copyWith({
    String? title,
    String? originalName,
    String? mimeType,
    String? extension,
    int? sizeBytes,
    String? storageKey,
    DateTime? updatedAt,
  }) {
    return BackgroundTrack(
      id: id,
      title: title ?? this.title,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      storageKey: storageKey ?? this.storageKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'originalName': originalName,
      'mimeType': mimeType,
      'extension': extension,
      'sizeBytes': sizeBytes,
      'storageKey': storageKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class MusicCatalog {
  const MusicCatalog._();

  static const int defaultSlotCount = 3;
  static const int slotUnlockCost = 30;
  static const int maxAudioFileBytes = 100 * 1024 * 1024;
  static const int maxTotalAudioBytes = 500 * 1024 * 1024;

  static BackgroundTrack? byId(
    List<BackgroundTrack> tracks,
    String id,
  ) {
    for (final track in tracks) {
      if (track.id == id) {
        return track;
      }
    }
    return null;
  }

  static String themedActionText(BackgroundTrack track) {
    return track.storageKey.trim().isEmpty ? '重新上传' : '播放音频';
  }
}

class MusicPlaybackState {
  const MusicPlaybackState({
    required this.currentTrackId,
    required this.playlistTrackIds,
    required this.loopMode,
    required this.volume,
    required this.isPlaying,
    required this.slotCount,
  });

  factory MusicPlaybackState.initial() {
    return const MusicPlaybackState(
      currentTrackId: '',
      playlistTrackIds: <String>[],
      loopMode: MusicLoopMode.playlist,
      volume: 0.72,
      isPlaying: false,
      slotCount: MusicCatalog.defaultSlotCount,
    );
  }

  factory MusicPlaybackState.fromJson(Map<String, dynamic> json) {
    final playlist = _readStringList(json['playlistTrackIds']);
    final current = json['currentTrackId']?.toString() ?? '';
    final loopMode = switch (json['loopMode']?.toString()) {
      'single' => MusicLoopMode.single,
      _ => MusicLoopMode.playlist,
    };
    final rawVolume = json['volume'];
    final rawSlotCount = _readInt(json['slotCount']);
    final slotCount = rawSlotCount < MusicCatalog.defaultSlotCount
        ? MusicCatalog.defaultSlotCount
        : rawSlotCount;
    return MusicPlaybackState(
      currentTrackId: playlist.contains(current) ? current : '',
      playlistTrackIds: playlist,
      loopMode: loopMode,
      volume: rawVolume is num ? rawVolume.toDouble().clamp(0.0, 1.0) : 0.72,
      isPlaying: json['isPlaying'] == true,
      slotCount: slotCount,
    );
  }

  final String currentTrackId;
  final List<String> playlistTrackIds;
  final MusicLoopMode loopMode;
  final double volume;
  final bool isPlaying;
  final int slotCount;

  BackgroundTrack? currentTrack(List<BackgroundTrack> tracks) =>
      MusicCatalog.byId(tracks, currentTrackId);

  bool ownsTrack(String id) => id.trim().isNotEmpty;

  bool get hasPlayablePlaylist => playlistTrackIds.isNotEmpty;

  MusicPlaybackState normalized(List<BackgroundTrack> tracks) {
    final knownIds = tracks.map((track) => track.id).toSet();
    final playlist = playlistTrackIds
        .where((id) => knownIds.contains(id))
        .toList(growable: false);
    final safeCurrent = knownIds.contains(currentTrackId) ? currentTrackId : '';
    return copyWith(
      currentTrackId: safeCurrent,
      playlistTrackIds: playlist,
      volume: volume.clamp(0.0, 1.0),
      isPlaying: safeCurrent.isNotEmpty && isPlaying,
      slotCount: slotCount < MusicCatalog.defaultSlotCount
          ? MusicCatalog.defaultSlotCount
          : slotCount,
    );
  }

  MusicPlaybackState copyWith({
    String? currentTrackId,
    List<String>? playlistTrackIds,
    MusicLoopMode? loopMode,
    double? volume,
    bool? isPlaying,
    int? slotCount,
  }) {
    return MusicPlaybackState(
      currentTrackId: currentTrackId ?? this.currentTrackId,
      playlistTrackIds: playlistTrackIds ?? this.playlistTrackIds,
      loopMode: loopMode ?? this.loopMode,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      slotCount: slotCount ?? this.slotCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currentTrackId': currentTrackId,
      'playlistTrackIds': playlistTrackIds,
      'loopMode': loopMode == MusicLoopMode.single ? 'single' : 'playlist',
      'volume': volume,
      'isPlaying': isPlaying,
      'slotCount': slotCount,
    };
  }
}

List<String> _readStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

int _readInt(Object? value) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _cleanTitle(String? value) {
  return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _titleFromFileName(String name) {
  final cleanName = name.trim();
  if (cleanName.isEmpty) {
    return '未命名音频';
  }
  final dotIndex = cleanName.lastIndexOf('.');
  final title = dotIndex > 0 ? cleanName.substring(0, dotIndex) : cleanName;
  final cleanTitle = _cleanTitle(title);
  return cleanTitle.isEmpty ? '未命名音频' : cleanTitle;
}
