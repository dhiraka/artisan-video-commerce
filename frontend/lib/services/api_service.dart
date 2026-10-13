import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '_gcs_upload_stub.dart' if (dart.library.html) '_gcs_upload_web.dart';
import '../config/app_config.dart';
import '../models/product.dart';
import '../models/order.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBase,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  // ── Video Upload ────────────────────────────────────────────────────────────

  Future<Map<String, String>> getUploadUrl(String filename, String contentType) async {
    final res = await _dio.post('/videos/upload-url', data: {
      'filename': filename,
      'content_type': contentType,
    });
    return {
      'upload_url': res.data['upload_url'] as String,
      'object_key': res.data['object_key'] as String,
    };
  }

  /// Upload video to GCS signed URL.
  /// On web: uses dart:html XHR + Blob (avoids single contiguous ArrayBuffer).
  /// On native: uses Dio streaming PUT.
  Future<void> uploadVideoToGcs({
    required String signedUrl,
    required Stream<List<int>> stream,
    required int fileSize,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      await uploadToGcsWeb(
        signedUrl: signedUrl,
        stream: stream,
        fileSize: fileSize,
        contentType: contentType,
        onProgress: onProgress,
      );
      return;
    }
    // Dio's onSendProgress doesn't fire for raw streams — track via wrapper.
    int bytesSent = 0;
    final trackedStream = onProgress == null
        ? stream
        : stream.map((chunk) {
            bytesSent += chunk.length;
            onProgress(bytesSent, fileSize);
            return chunk;
          });

    final uploadDio = Dio();
    await uploadDio.put(
      signedUrl,
      data: trackedStream,
      options: Options(
        headers: {
          HttpHeaders.contentTypeHeader: contentType,
          HttpHeaders.contentLengthHeader: fileSize,
        },
        sendTimeout: const Duration(minutes: 60),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
  }

  Future<void> notifyUploadComplete(String productId, String objectKey) async {
    await _dio.post('/videos/notify', data: {
      'product_id': productId,
      'object_key': objectKey,
    });
  }

  Future<Map<String, dynamic>> getVideoStatus(String productId) async {
    final res = await _dio.get('/videos/$productId/status');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── Products ────────────────────────────────────────────────────────────────

  Future<Product> createProduct({
    required String title,
    required String description,
    required double price,
    required List<String> tags,
    required String artisanName,
    required String videoObjectKey,
  }) async {
    final res = await _dio.post('/products', data: {
      'title': title,
      'description': description,
      'price': price,
      'tags': tags,
      'artisan_name': artisanName,
      'video_object_key': videoObjectKey,
    });
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  Future<bool> checkTitleExists(String title) async {
    final res = await _dio.get('/products/check-title', queryParameters: {'title': title});
    return res.data['exists'] as bool;
  }

  Future<List<Product>> searchProducts({String query = '', List<String> tags = const []}) async {
    final res = await _dio.get('/products', queryParameters: {
      if (query.isNotEmpty) 'q': query,
      if (tags.isNotEmpty) 'tags': tags.join(','),
    });
    final list = res.data as List;
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> getProduct(String productId) async {
    final res = await _dio.get('/products/$productId');
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Orders ──────────────────────────────────────────────────────────────────

  Future<Order> placeOrder({
    required String productId,
    required String buyerName,
    required String buyerEmail,
    required int quantity,
    required String shippingAddress,
  }) async {
    final res = await _dio.post('/orders', data: {
      'product_id': productId,
      'buyer_name': buyerName,
      'buyer_email': buyerEmail,
      'quantity': quantity,
      'shipping_address': shippingAddress,
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> listOrders() async {
    final res = await _dio.get('/orders');
    return (res.data as List).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(String orderId) async {
    final res = await _dio.get('/orders/$orderId');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}
