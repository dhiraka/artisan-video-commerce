import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> uploadToGcsWeb({
  required String signedUrl,
  required Stream<List<int>> stream,
  required int fileSize,
  required String contentType,
  void Function(int sent, int total)? onProgress,
}) async {
  // Collect stream into small Uint8List chunks — each chunk is a small ArrayBuffer.
  // Blob holds references to these fragments without requiring one contiguous allocation.
  final parts = <Object>[];
  await for (final chunk in stream) {
    parts.add(Uint8List.fromList(chunk));
  }

  final blob = html.Blob(parts, contentType);
  final completer = Completer<void>();
  final xhr = html.HttpRequest();

  xhr.open('PUT', signedUrl);
  xhr.setRequestHeader('Content-Type', contentType);

  if (onProgress != null) {
    xhr.upload.onProgress.listen((e) {
      if (e.lengthComputable) onProgress(e.loaded!, e.total!);
    });
  }

  xhr.onLoad.listen((_) {
    final status = xhr.status ?? 0;
    if (status >= 200 && status < 300) {
      completer.complete();
    } else {
      completer.completeError(
        Exception('GCS upload failed: $status ${xhr.responseText}'),
      );
    }
  });

  xhr.onError.listen((_) {
    completer.completeError(Exception('Upload network error'));
  });

  xhr.send(blob);
  await completer.future;
}
