import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../services/api_service.dart';

enum UploadStep { idle, pickingFile, uploading, creatingProduct, transcoding, done, error }

class UploadProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  UploadStep _step = UploadStep.idle;
  double _uploadProgress = 0;
  String? _errorMessage;
  Product? _product;
  PlatformFile? _selectedFile;

  String savedTitle = '';
  String savedDesc = '';
  String savedPrice = '';
  String savedName = '';
  String savedTags = '';

  UploadStep get step => _step;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;
  Product? get product => _product;
  PlatformFile? get selectedFile => _selectedFile;

  void saveFormValues({
    required String title,
    required String desc,
    required String price,
    required String name,
    required String tags,
  }) {
    savedTitle = title;
    savedDesc = desc;
    savedPrice = price;
    savedName = name;
    savedTags = tags;
  }

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: false,
      withReadStream: true,
    );
    if (result != null) {
      _selectedFile = result.files.single;
      notifyListeners();
    }
  }

  Future<void> uploadAndCreate({
    required String title,
    required String description,
    required double price,
    required List<String> tags,
    required String artisanName,
  }) async {
    if (_selectedFile == null) return;

    try {
      _step = UploadStep.uploading;
      _uploadProgress = 0;
      _errorMessage = null;
      notifyListeners();

      final filename = _selectedFile!.name;
      final contentType = _mimeType(filename);
      final fileSize = _selectedFile!.size;
      final readStream = _selectedFile!.readStream;
      if (readStream == null) throw Exception('Could not read video file stream.');

      // 1. Get signed GCS upload URL
      final urlData = await _api.getUploadUrl(filename, contentType);
      final signedUrl = urlData['upload_url']!;
      final objectKey = urlData['object_key']!;

      // 2. Upload video as a stream directly to GCS (avoids loading file into memory)
      await _api.uploadVideoToGcs(
        signedUrl: signedUrl,
        stream: readStream,
        fileSize: fileSize,
        contentType: contentType,
        onProgress: (sent, total) {
          _uploadProgress = total > 0 ? sent / total : 0;
          notifyListeners();
        },
      );

      // 3. Create product record in Firestore
      _step = UploadStep.creatingProduct;
      notifyListeners();

      _product = await _api.createProduct(
        title: title,
        description: description,
        price: price,
        tags: tags,
        artisanName: artisanName,
        videoObjectKey: objectKey,
      );

      // 4. Notify backend → triggers GCP Transcoder job
      await _api.notifyUploadComplete(_product!.id, objectKey);

      // Mark done immediately — transcoding runs in background on GCP.
      // The product will show as "Processing" in the catalogue until ready.
      _step = UploadStep.done;
      notifyListeners();
    } on DioException catch (e) {
      _step = UploadStep.error;
      final detail = e.response?.data?['detail'];
      _errorMessage = detail is String ? detail : e.message ?? e.toString();
      notifyListeners();
    } catch (e) {
      _step = UploadStep.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void reset() {
    _step = UploadStep.idle;
    _uploadProgress = 0;
    _errorMessage = null;
    _product = null;
    _selectedFile = null;
    savedTitle = '';
    savedDesc = '';
    savedPrice = '';
    savedName = '';
    savedTags = '';
    notifyListeners();
  }

  String _mimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    const map = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
    };
    return map[ext] ?? 'video/mp4';
  }
}
