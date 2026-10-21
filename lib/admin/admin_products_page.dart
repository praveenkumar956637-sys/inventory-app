import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/product_search_field.dart';
import '../widgets/state_views.dart';
import 'widgets/admin_product_card.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({
    super.key,
    required this.products,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  /// Live product list, provided by AdminShell.
  final List<ProductModel> products;
  final VoidCallback onAddProduct;
  final void Function(ProductModel product) onEditProduct;
  final void Function(ProductModel product) onDeleteProduct;

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final List<ProductModel> filtered = ProductService.filter(
      widget.products,
      _query,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ProductSearchField(
              controller: _searchController,
              showClear: _query.isNotEmpty,
              onChanged: (String value) => setState(() => _query = value),
              onClear: _clearSearch,
            ),
          ),
          Expanded(child: _buildList(filtered)),
        ],
      ),
    );
  }

  Widget _buildList(List<ProductModel> filtered) {
    if (widget.products.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: 'No products available',
        message: 'Tap "Add Product" to create the first one.',
      );
    }
    if (filtered.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        title: 'No products match your search',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        final ProductModel product = filtered[index];
        return AdminProductCard(
          key: ValueKey<String>(product.id),
          product: product,
          onEdit: () => widget.onEditProduct(product),
          onDelete: () => widget.onDeleteProduct(product),
        );
      },
    );
  }
}
