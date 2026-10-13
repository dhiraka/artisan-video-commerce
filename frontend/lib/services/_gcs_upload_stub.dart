Future<void> uploadToGcsWeb({
  required String signedUrl,
  required Stream<List<int>> stream,
  required int fileSize,
  required String contentType,
  void Function(int sent, int total)? onProgress,
}) => throw UnsupportedError('Web-only');
