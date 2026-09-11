class StoredAudioFile {
  const StoredAudioFile({
    required this.storageKey,
    required this.playbackUri,
    required this.sizeBytes,
  });

  final String storageKey;
  final String playbackUri;
  final int sizeBytes;
}
