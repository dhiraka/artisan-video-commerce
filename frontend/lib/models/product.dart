class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> tags;
  final String artisanName;
  final String videoObjectKey;
  final String status;
  final String? hlsManifestUrl;
  final String? thumbnailUrl;
  final String createdAt;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.tags,
    required this.artisanName,
    required this.videoObjectKey,
    required this.status,
    this.hlsManifestUrl,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        tags: List<String>.from(json['tags'] as List? ?? []),
        artisanName: json['artisan_name'] as String,
        videoObjectKey: json['video_object_key'] as String,
        status: json['status'] as String,
        hlsManifestUrl: json['hls_manifest_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        createdAt: json['created_at'] as String,
      );

  bool get isReady => status == 'ready';

  // Derive thumbnail from HLS URL if not explicitly stored
  String? get effectiveThumbnailUrl {
    if (thumbnailUrl != null) return thumbnailUrl;
    if (hlsManifestUrl != null) {
      return hlsManifestUrl!.replaceFirst('manifest.m3u8', 'thumbnail000000000.jpeg');
    }
    return null;
  }
}
