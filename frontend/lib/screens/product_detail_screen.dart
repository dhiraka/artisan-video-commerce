import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/video_player_widget.dart';
import 'order_confirmation_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _api = ApiService();
  Product? _product;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  int _pollAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      final p = await _api.getProduct(widget.productId);
      setState(() {
        _product = p;
        _loading = false;
      });
      if (!p.isReady && p.status != 'failed') {
        _startPolling();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(AppConfig.pollingInterval, (_) async {
      if (_pollAttempts++ >= AppConfig.pollingMaxAttempts) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final status = await _api.getVideoStatus(widget.productId);
        final s = status['status'] as String;
        if (s == 'ready' || s == 'failed') {
          _pollTimer?.cancel();
          if (mounted) await _loadProduct();
        }
      } catch (_) {
        // keep polling on transient errors
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }

    final product = _product!;
    final isTablet = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: isTablet
          ? _TabletLayout(product: product)
          : _PhoneLayout(product: product),
    );
  }
}

class _PhoneLayout extends StatelessWidget {
  final Product product;
  const _PhoneLayout({required this.product});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VideoSection(product: product),
          _ProductInfo(product: product),
          _OrderSection(product: product),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
  final Product product;
  const _TabletLayout({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _VideoSection(product: product),
                _ProductInfo(product: product),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _OrderSection(product: product),
          ),
        ),
      ],
    );
  }
}

class _VideoSection extends StatelessWidget {
  final Product product;
  const _VideoSection({required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.isReady || product.hlsManifestUrl == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text('Video is being processed...',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    return VideoPlayerWidget(
      hlsUrl: product.hlsManifestUrl!,
      thumbnailUrl: product.effectiveThumbnailUrl,
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final Product product;
  const _ProductInfo({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(product.title, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(width: 12),
              Text(
                '₹${product.price.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16),
              const SizedBox(width: 4),
              Text('by ${product.artisanName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
          if (product.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: product.tags
                  .map((t) => Chip(
                        label: Text(t),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text('About this piece', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(product.description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _OrderSection extends StatefulWidget {
  final Product product;
  const _OrderSection({required this.product});

  @override
  State<_OrderSection> createState() => _OrderSectionState();
}

class _OrderSectionState extends State<_OrderSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  int _quantity = 1;
  bool _placing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _placing = true);
    try {
      final order = await ApiService().placeOrder(
        productId: widget.product.id,
        buyerName: _nameController.text.trim(),
        buyerEmail: _emailController.text.trim(),
        quantity: _quantity,
        shippingAddress: _addressController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(order: order),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 720;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 0 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isTablet) ...[
              const Divider(),
              const SizedBox(height: 8),
            ],
            Text('Place Your Order', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Shipping Address',
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
              validator: (v) => v == null || v.trim().length < 10 ? 'Enter full address' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quantity:'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
                Text('$_quantity', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: theme.textTheme.titleMedium),
                  Text(
                    '₹${(widget.product.price * _quantity).toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: !_placing ? _placeOrder : null,
              icon: _placing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.shopping_bag),
              label: Text(_placing ? 'Placing Order...' : 'Place Order'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
