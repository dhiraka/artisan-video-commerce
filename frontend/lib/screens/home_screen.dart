import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/products_provider.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  static const _popularTags = [
    'pottery', 'woodwork', 'jewelry', 'weaving', 'painting',
    'leather', 'ceramics', 'candles', 'soap', 'knitting',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artisan Market'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _SearchBar(controller: _searchController),
        ),
      ),
      body: Column(
        children: [
          _TagFilterRow(tags: _popularTags),
          Expanded(child: _ProductGrid()),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SearchBar(
        controller: controller,
        hintText: 'Search handmade goods...',
        leading: const Icon(Icons.search),
        trailing: [
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                controller.clear();
                context.read<ProductsProvider>().setSearch('');
              },
            ),
        ],
        onChanged: (value) => context.read<ProductsProvider>().setSearch(value),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      ),
    );
  }
}

class _TagFilterRow extends StatelessWidget {
  final List<String> tags;
  const _TagFilterRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final selected = provider.selectedTags.contains(tag);
          return FilterChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) => provider.toggleTag(tag),
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(provider.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: provider.fetchProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: provider.clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    // Responsive: 2 columns on phone, 3-4 on tablet
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 2 : (width < 900 ? 3 : 4);

    return RefreshIndicator(
      onRefresh: provider.fetchProducts,
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          final product = provider.products[index];
          return ProductCard(
            product: product,
            onTap: () => _openProduct(context, product),
          );
        },
      ),
    );
  }

  void _openProduct(BuildContext context, Product product) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productId: product.id),
    ));
    if (context.mounted) {
      context.read<ProductsProvider>().fetchProducts();
    }
  }
}
