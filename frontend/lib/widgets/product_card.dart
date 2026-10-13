import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/product.dart';
import '_web_player_stub.dart' if (dart.library.html) '_web_player_web.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: _hovered ? 6 : 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MediaPreview(
                product: widget.product,
                hovered: _hovered,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${widget.product.artisanName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${widget.product.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.product.isReady)
                          Icon(Icons.play_circle_outline,
                              color: theme.colorScheme.primary, size: 20),
                      ],
                    ),
                    if (widget.product.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: widget.product.tags
                            .take(3)
                            .map((t) => _TagChip(tag: t))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  final Product product;
  final bool hovered;

  const _MediaPreview({required this.product, required this.hovered});

  @override
  Widget build(BuildContext context) {
    final hlsUrl = product.hlsManifestUrl;

    // On web: show muted autoplay video on hover when HLS is ready
    if (kIsWeb && hovered && product.isReady && hlsUrl != null) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: WebVideoPlayer(
          hlsUrl: hlsUrl,
          muted: true,
          autoplay: true,
          showControls: false,
        ),
      );
    }

    return _Thumbnail(url: product.effectiveThumbnailUrl);
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: 140,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.videocam_outlined,
              size: 48, color: Theme.of(context).colorScheme.outlineVariant),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      height: 140,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(height: 140, color: Colors.white),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 140,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined, size: 40),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
