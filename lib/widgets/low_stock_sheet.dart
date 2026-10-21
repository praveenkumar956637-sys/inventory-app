import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';

/// Bottom sheet listing Low Stock and Out of Stock products, updated live.
/// [itemBuilder] picks the card (Admin or Staff) for each product.
Future<void> showLowStockSheet(
  BuildContext context, {
  required Stream<List<ProductModel>> stream,
  required Widget Function(ProductModel product) itemBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.lightGrey,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) {
      return _LowStockSheet(stream: stream, itemBuilder: itemBuilder);
    },
  );
}

class _LowStockSheet extends StatelessWidget {
  const _LowStockSheet({required this.stream, required this.itemBuilder});

  final Stream<List<ProductModel>> stream;
  final Widget Function(ProductModel product) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 10),
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: <Widget>[
                  Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.redTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Low Stock Alerts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<List<ProductModel>>(
                stream: stream,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<ProductModel>> snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            AppException.messageOf(snapshot.error!),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final List<ProductModel> alerts =
                          ProductService.lowStockProducts(snapshot.data!);
                      if (alerts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                height: 64,
                                width: 64,
                                decoration: const BoxDecoration(
                                  color: AppColors.greenTint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.green,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No low-stock products. Everything is well stocked.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: alerts.length,
                        itemBuilder: (BuildContext context, int index) {
                          return itemBuilder(alerts[index]);
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
