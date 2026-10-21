import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../widgets/app_card.dart';
import '../../widgets/product_summary.dart';

/// Product card for the Admin section.
/// The Edit/Delete row only appears when [onEdit] or [onDelete] is given,
/// so the same card can be used as a compact alert row.
class AdminProductCard extends StatelessWidget {
  const AdminProductCard({
    super.key,
    required this.product,
    this.onEdit,
    this.onDelete,
  });

  final ProductModel product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bool showActions = onEdit != null || onDelete != null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ProductSummary(product: product),
          if (showActions) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ),
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: 10),
                if (onDelete != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: AppColors.primaryRed,
                        side: const BorderSide(color: AppColors.primaryRed),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
