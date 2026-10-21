import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/sale_service.dart';
import '../services/stock_service.dart';
import '../widgets/app_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/transaction_tile.dart';
import 'excel_export_sheet.dart';
import 'excel_import_page.dart';
import 'widgets/admin_product_card.dart';
import 'widgets/admin_summary_card.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.products,
    required this.onAddProduct,
    required this.onStockIn,
    required this.onStockOut,
    required this.onRecordSale,
    required this.onOpenAlerts,
  });

  /// Live product list, provided by AdminShell.
  final List<ProductModel> products;
  final VoidCallback onAddProduct;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onRecordSale;
  final VoidCallback onOpenAlerts;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AuthService _authService = AuthService();
  final StockService _stockService = StockService();
  final SaleService _saleService = SaleService();

  late Stream<List<StockMovementModel>> _movementsStream;
  late Stream<List<SaleModel>> _todaySalesStream;
  Map<String, String> _userNames = <String, String>{};
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _movementsStream = _stockService.streamRecentMovements(limit: 10);
    _todaySalesStream = _saleService.streamTodaySales();
    _loadUserNames();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserNames() async {
    try {
      final Map<String, String> names = await _authService.getUserNameMap();
      if (!mounted) return;
      setState(() => _userNames = names);
    } catch (_) {
      // Keep the old names; tiles show "Unknown" for missing ones.
    }
  }

  /// "Today's Sales" is counted from midnight, so restart that stream
  /// when a new day begins while the app is open.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() {
          _todaySalesStream = _saleService.streamTodaySales();
        });
        _scheduleMidnightRefresh();
      },
    );
  }

  void _openImport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ExcelImportPage(),
      ),
    );
  }

  void _openExport() {
    showExportReportSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<ProductModel> products = widget.products;
    final List<ProductModel> alerts = ProductService.lowStockProducts(products);
    final Map<String, String> productNames = <String, String>{
      for (final ProductModel p in products) p.id: p.name,
    };

    final String? uid = _authService.currentUser?.uid;
    final String name = (uid == null ? null : _userNames[uid]) ?? 'Admin';

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadUserNames,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DashboardHeader(name: name, roleLabel: 'Admin'),
          const SizedBox(height: 16),
          _buildSummary(products, alerts.length),
          const SectionHeader(title: 'Quick Actions'),
          _buildQuickActions(),
          SectionHeader(
            title: 'Low Stock Alerts',
            trailing: alerts.isEmpty
                ? null
                : TextButton(
                    onPressed: widget.onOpenAlerts,
                    child: Text(
                      alerts.length > 3
                          ? 'View all (${alerts.length})'
                          : 'View all',
                    ),
                  ),
          ),
          if (alerts.isEmpty)
            _infoBox(
              icon: Icons.check_circle_outline,
              color: AppColors.green,
              tint: AppColors.greenTint,
              message: 'All products are well stocked.',
            )
          else
            ...alerts
                .take(3)
                .map((ProductModel p) => AdminProductCard(product: p)),
          const SectionHeader(title: 'Recent Transactions'),
          _buildTransactions(productNames),
        ],
      ),
    );
  }

  Widget _buildSummary(List<ProductModel> products, int lowCount) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AdminSummaryCard(
                title: 'Total Products',
                value: products.length.toString(),
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.darkBlack,
                tintColor: AppColors.blackTint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminSummaryCard(
                title: 'Available Stock',
                value: ProductService.totalQuantity(products).toString(),
                icon: Icons.layers_outlined,
                iconColor: AppColors.green,
                tintColor: AppColors.greenTint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: AdminSummaryCard(
                title: 'Low Stock Items',
                value: lowCount.toString(),
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.primaryRed,
                tintColor: AppColors.redTint,
                onTap: widget.onOpenAlerts,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<List<SaleModel>>(
                stream: _todaySalesStream,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<SaleModel>> snapshot,
                    ) {
                      final String value;
                      if (snapshot.hasError) {
                        value = '--';
                      } else if (!snapshot.hasData) {
                        value = '...';
                      } else {
                        value = Formatters.rupees(
                          SaleService.todayTotal(snapshot.data!),
                        );
                      }
                      return AdminSummaryCard(
                        title: "Today's Sales",
                        value: value,
                        icon: Icons.currency_rupee,
                        iconColor: AppColors.green,
                        tintColor: AppColors.greenTint,
                      );
                    },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Two rows of three buttons: product and stock actions, then sales and Excel.
  Widget _buildQuickActions() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: QuickActionButton(
                  icon: Icons.add_box_outlined,
                  label: 'Add Product',
                  onTap: widget.onAddProduct,
                ),
              ),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Stock In',
                  color: AppColors.green,
                  onTap: widget.onStockIn,
                ),
              ),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Stock Out',
                  color: AppColors.darkBlack,
                  onTap: widget.onStockOut,
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: QuickActionButton(
                  icon: Icons.point_of_sale,
                  label: 'Record Sale',
                  onTap: widget.onRecordSale,
                ),
              ),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.file_upload_outlined,
                  label: 'Import Excel',
                  color: AppColors.darkBlack,
                  onTap: _openImport,
                ),
              ),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.file_download_outlined,
                  label: 'Export Excel',
                  color: AppColors.green,
                  onTap: _openExport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactions(Map<String, String> productNames) {
    return StreamBuilder<List<StockMovementModel>>(
      stream: _movementsStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StockMovementModel>> snapshot,
          ) {
            if (snapshot.hasError) {
              return _infoBox(
                icon: Icons.error_outline,
                color: AppColors.primaryRed,
                tint: AppColors.redTint,
                message: AppException.messageOf(snapshot.error!),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final List<StockMovementModel> movements = snapshot.data!;
            if (movements.isEmpty) {
              return _infoBox(
                icon: Icons.receipt_long_outlined,
                color: AppColors.darkBlack,
                tint: AppColors.blackTint,
                message: 'No transactions yet.',
              );
            }
            return Column(
              children: movements
                  .map(
                    (StockMovementModel m) => TransactionTile(
                      movement: m,
                      productName:
                          productNames[m.productId] ?? 'Deleted product',
                      userName: _userNames[m.userId] ?? 'Unknown',
                    ),
                  )
                  .toList(),
            );
          },
    );
  }

  Widget _infoBox({
    required IconData icon,
    required Color color,
    required Color tint,
    required String message,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.darkBlack),
            ),
          ),
        ],
      ),
    );
  }
}
