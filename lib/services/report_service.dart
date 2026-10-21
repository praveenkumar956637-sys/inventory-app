import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import 'auth_service.dart';
import 'excel_service.dart';

enum ReportType { inventory, sales, stockMovements, lowStock }

extension ReportTypeInfo on ReportType {
  String get title {
    switch (this) {
      case ReportType.inventory:
        return 'Inventory Report';
      case ReportType.sales:
        return 'Sales Report';
      case ReportType.stockMovements:
        return 'Stock Movement Report';
      case ReportType.lowStock:
        return 'Low Stock Report';
    }
  }

  String get description {
    switch (this) {
      case ReportType.inventory:
        return 'Name, code, category, quantity, price and minimum stock';
      case ReportType.sales:
        return 'Date, items, quantities, total amount and user';
      case ReportType.stockMovements:
        return 'Type, product, quantity, date and user';
      case ReportType.lowStock:
        return 'Products at or below their minimum stock';
    }
  }

  String get fileBaseName {
    switch (this) {
      case ReportType.inventory:
        return 'inventory_report';
      case ReportType.sales:
        return 'sales_report';
      case ReportType.stockMovements:
        return 'stock_movement_report';
      case ReportType.lowStock:
        return 'low_stock_report';
    }
  }
}

/// A finished Excel file, ready to save or share.
class GeneratedReport {
  const GeneratedReport({
    required this.fileName,
    required this.bytes,
    required this.rowCount,
  });

  final String fileName;
  final Uint8List bytes;
  final int rowCount;
}

/// Reads real data from Firestore and turns it into an Excel report.
/// Admin only.
class ReportService {
  ReportService({FirebaseFirestore? firestore, AuthService? authService})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = authService ?? AuthService();

  final FirebaseFirestore _db;
  final AuthService _auth;

  Future<GeneratedReport> generate(ReportType type) async {
    try {
      await _auth.requireAdmin();

      switch (type) {
        case ReportType.inventory:
          final List<ProductModel> products = await _loadProducts();
          _requireData(products.length);
          return _report(
            type,
            ExcelService.inventoryReport(products),
            products.length,
          );

        case ReportType.lowStock:
          final List<ProductModel> low =
              (await _loadProducts())
                  .where((ProductModel p) => p.isLowOrOut)
                  .toList()
                ..sort(
                  (ProductModel a, ProductModel b) =>
                      a.quantity.compareTo(b.quantity),
                );
          _requireData(low.length);
          return _report(type, ExcelService.lowStockReport(low), low.length);

        case ReportType.sales:
          final List<SaleModel> sales = await _loadSales();
          _requireData(sales.length);
          final Map<String, String> userNames = await _auth.getUserNameMap();
          return _report(
            type,
            ExcelService.salesReport(sales, userNames),
            sales.length,
          );

        case ReportType.stockMovements:
          final List<StockMovementModel> movements = await _loadMovements();
          _requireData(movements.length);
          final List<ProductModel> products = await _loadProducts();
          final Map<String, String> productNames = <String, String>{
            for (final ProductModel p in products) p.id: p.name,
          };
          final Map<String, String> userNames = await _auth.getUserNameMap();
          return _report(
            type,
            ExcelService.stockMovementReport(
              movements,
              productNames,
              userNames,
            ),
            movements.length,
          );
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<ProductModel>> _loadProducts() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('products')
        .get();
    final List<ProductModel> list = snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              ProductModel.fromMap(doc.data(), doc.id),
        )
        .toList();
    list.sort(
      (ProductModel a, ProductModel b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  Future<List<SaleModel>> _loadSales() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('sales')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              SaleModel.fromMap(doc.data(), doc.id),
        )
        .toList();
  }

  Future<List<StockMovementModel>> _loadMovements() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('stock_movements')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              StockMovementModel.fromMap(doc.data(), doc.id),
        )
        .toList();
  }

  void _requireData(int count) {
    if (count == 0) {
      throw const AppException('There is no data to export for this report.');
    }
  }

  GeneratedReport _report(ReportType type, Uint8List bytes, int rowCount) {
    return GeneratedReport(
      fileName: '${type.fileBaseName}_${_today()}.xlsx',
      bytes: bytes,
      rowCount: rowCount,
    );
  }

  String _today() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
