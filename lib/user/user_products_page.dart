import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/product_search_field.dart';
import '../widgets/state_views.dart';
import 'widgets/user_product_card.dart';

class UserProductsPage extends StatefulWidget {
  const UserProductsPage({super.key, required this.products});

  /// Live product list, provided by UserShell.
  final List<ProductModel> products;

  @override
  State<UserProductsPage> createState() => _UserProductsPageState();
}

class _UserProductsPageState extends State<UserProductsPage> {
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

    return Column(
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
    );
  }

  Widget _buildList(List<ProductModel> filtered) {
    if (widget.products.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: 'No products available',
      );
    }
    if (filtered.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        title: 'No products match your search',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        final ProductModel product = filtered[index];
        return UserProductCard(
          key: ValueKey<String>(product.id),
          product: product,
        );
      },
    );
  }
}
