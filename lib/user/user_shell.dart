import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/low_stock_sheet.dart';
import '../widgets/state_views.dart';
import '../widgets/stock_dialogs.dart';
import 'user_dashboard_page.dart';
import 'user_products_page.dart';
import 'widgets/user_product_card.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  static const List<String> _titles = <String>['Dashboard', 'Products'];

  static const List<AppNavItem> _navItems = <AppNavItem>[
    AppNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    AppNavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Products',
    ),
  ];

  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService();

  late Stream<List<ProductModel>> _productsStream;

  int _index = 0;
  bool _verifying = true;
  bool _loggingOut = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _productsStream = _productService.streamProducts();
    _verifyUser();
  }

  /// The account must still be active with a valid role.
  Future<void> _verifyUser() async {
    try {
      await _authService.requireActiveUser();
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifyError = AppException.messageOf(e);
      });
    }
  }

  void _retryVerify() {
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    _verifyUser();
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          icon: Icons.logout,
          title: 'Logout',
          confirmLabel: 'Logout',
          onConfirm: () => Navigator.of(dialogContext).pop(true),
          onCancel: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(fontSize: 15, color: AppColors.darkBlack),
          ),
        );
      },
    );
    if (confirmed == true && mounted) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      AppRoutes.goAndClearStack(context, AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      showErrorSnackBar(context, AppException.messageOf(e));
    }
  }

  Future<void> _openStock(
    StockDialogMode mode,
    List<ProductModel> products,
  ) async {
    final String? message = await showStockDialog(
      context,
      mode: mode,
      products: products,
    );
    if (!mounted || message == null) return;
    showSuccessSnackBar(context, message);
  }

  Future<void> _openSale(List<ProductModel> products) async {
    final String? message = await showRecordSaleDialog(
      context,
      products: products,
    );
    if (!mounted || message == null) return;
    showSuccessSnackBar(context, message);
  }

  void _openAlerts() {
    showLowStockSheet(
      context,
      stream: _productService.streamProducts(),
      itemBuilder: (ProductModel product) => UserProductCard(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verifying || _loggingOut) {
      return const Scaffold(body: LoadingView());
    }

    if (_verifyError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: ErrorStateView(
          message: _verifyError!,
          onRetry: _retryVerify,
          onLogout: _logout,
        ),
      );
    }

    return StreamBuilder<List<ProductModel>>(
      stream: _productsStream,
      builder:
          (BuildContext context, AsyncSnapshot<List<ProductModel>> snapshot) {
            final List<ProductModel> products =
                snapshot.data ?? const <ProductModel>[];
            final int alertCount = ProductService.lowStockProducts(products)
                .length;
            final bool waiting = !snapshot.hasData && !snapshot.hasError;
            final bool failed = !snapshot.hasData && snapshot.hasError;

            final Widget body;
            if (waiting) {
              body = const LoadingView();
            } else if (failed) {
              body = ErrorStateView(
                message: AppException.messageOf(snapshot.error!),
                onRetry: () {
                  setState(() {
                    _productsStream = _productService.streamProducts();
                  });
                },
              );
            } else {
              body = IndexedStack(
                index: _index,
                children: <Widget>[
                  UserDashboardPage(
                    products: products,
                    onStockIn: () =>
                        _openStock(StockDialogMode.stockIn, products),
                    onStockOut: () =>
                        _openStock(StockDialogMode.stockOut, products),
                    onRecordSale: () => _openSale(products),
                    onOpenAlerts: _openAlerts,
                  ),
                  UserProductsPage(products: products),
                ],
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(_titles[_index]),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Low stock alerts',
                    onPressed: _openAlerts,
                    icon: Badge(
                      isLabelVisible: alertCount > 0,
                      label: Text(alertCount > 99 ? '99+' : '$alertCount'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: body,
              bottomNavigationBar: AppBottomNav(
                currentIndex: _index,
                onTap: (int i) => setState(() => _index = i),
                items: _navItems,
              ),
            );
          },
    );
  }
}
