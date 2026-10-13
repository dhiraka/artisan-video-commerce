import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Product> _products = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  List<String> _selectedTags = [];

  List<Product> get products => _products;
  bool get loading => _loading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get selectedTags => _selectedTags;

  Future<void> fetchProducts() async {
    if (_products.isEmpty) {
      _loading = true;
      notifyListeners();
    }
    _error = null;
    try {
      _products = await _api.searchProducts(query: _searchQuery, tags: _selectedTags);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setSearch(String query) {
    _searchQuery = query;
    fetchProducts();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags = List.from(_selectedTags)..remove(tag);
    } else {
      _selectedTags = List.from(_selectedTags)..add(tag);
    }
    fetchProducts();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTags = [];
    fetchProducts();
  }
}
