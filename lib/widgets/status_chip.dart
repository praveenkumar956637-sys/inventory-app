import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/product_model.dart';

/// Small pill with a colored dot, used for stock status and account status.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.tint,
  });

  /// In Stock is green. Low Stock and Out of Stock are red.
  factory StatusChip.product(ProductModel product) {
    final bool inStock = product.status == StockStatus.inStock;
    return StatusChip(
      label: product.statusLabel,
      color: inStock ? AppColors.green : AppColors.primaryRed,
      tint: inStock ? AppColors.greenTint : AppColors.redTint,
    );
  }

  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 7,
            width: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
