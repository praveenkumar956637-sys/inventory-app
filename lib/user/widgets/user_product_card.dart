import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../widgets/app_card.dart';
import '../../widgets/product_summary.dart';

/// Read-only product card for the Staff section (no Edit or Delete).
class UserProductCard extends StatelessWidget {
  const UserProductCard({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: ProductSummary(product: product),
    );
  }
}
