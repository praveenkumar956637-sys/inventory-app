import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/stock_movement_model.dart';
import 'app_card.dart';
import 'status_chip.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.movement,
    required this.productName,
    required this.userName,
  });

  final StockMovementModel movement;
  final String productName;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final bool isIn = movement.type == StockMovementType.stockIn;
    final bool isSale = movement.type == StockMovementType.sale;

    final IconData icon;
    final Color color;
    final Color tint;
    if (isIn) {
      icon = Icons.add_circle_outline;
      color = AppColors.green;
      tint = AppColors.greenTint;
    } else if (isSale) {
      icon = Icons.point_of_sale;
      color = AppColors.darkBlack;
      tint = AppColors.blackTint;
    } else {
      icon = Icons.remove_circle_outline;
      color = AppColors.primaryRed;
      tint = AppColors.redTint;
    }

    final String quantityText = isIn
        ? '+${movement.quantity}'
        : '-${movement.quantity}';
    final Color quantityColor = isIn ? AppColors.green : AppColors.primaryRed;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Formatters.date(movement.date)} • '
                  '${Formatters.time(movement.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'By $userName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                quantityText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: quantityColor,
                ),
              ),
              const SizedBox(height: 6),
              StatusChip(label: movement.type, color: color, tint: tint),
            ],
          ),
        ],
      ),
    );
  }
}
