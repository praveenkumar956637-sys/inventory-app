import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// One line the user chose in the Record Sale dialog.
/// Only the product and quantity are sent; the price is read from the database.
class SaleLineRequest {
  final String productId;
  final int quantity;

  const SaleLineRequest({required this.productId, required this.quantity});
}

class SaleService {
  SaleService({FirebaseFirestore? firestore, AuthService? authService})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = authService ?? AuthService();

  final FirebaseFirestore _db;
  final AuthService _auth;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('sales');

  /// Validates stock, decreases inventory, creates the sale document and one
  /// "Sale" stock movement per product, all in a single transaction.
  /// Allowed for Admin and Staff.
  Future<SaleModel> recordSale(List<SaleLineRequest> lines) async {
    try {
      final UserModel profile = await _auth.requireActiveUser();

      if (lines.isEmpty) {
        throw const AppException('Add at least one product to the sale.');
      }

      // Merge duplicate products so the same stock is not checked twice.
      final Map<String, int> wanted = <String, int>{};
      for (final SaleLineRequest line in lines) {
        if (line.productId.isEmpty) {
          throw const AppException('Please select a product for every line.');
        }
        if (line.quantity <= 0) {
          throw const AppException('Quantity must be greater than zero.');
        }
        wanted[line.productId] = (wanted[line.productId] ?? 0) + line.quantity;
      }

      final DocumentReference<Map<String, dynamic>> saleRef = _sales.doc();
      final DateTime now = DateTime.now();
      late SaleModel sale;

      await _db.runTransaction((Transaction tx) async {
        // Firestore requires all reads before any writes.
        final List<ProductModel> products = <ProductModel>[];
        for (final String productId in wanted.keys) {
          final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(
            _products.doc(productId),
          );
          final Map<String, dynamic>? data = snap.data();
          if (!snap.exists || data == null) {
            throw const AppException('A selected product no longer exists.');
          }
          final ProductModel product = ProductModel.fromMap(data, snap.id);
          final int qty = wanted[productId] ?? 0;
          if (qty > product.quantity) {
            throw AppException(
              'Insufficient stock for ${product.name}. '
              'Available: ${product.quantity}',
            );
          }
          products.add(product);
        }

        final List<SaleItem> items = <SaleItem>[];
        for (final ProductModel product in products) {
          final int qty = wanted[product.id] ?? 0;
          items.add(
            SaleItem(
              productId: product.id,
              productName: product.name,
              quantity: qty,
              price: product.price,
            ),
          );

          tx.update(_products.doc(product.id), <String, dynamic>{
            'quantity': product.quantity - qty,
          });

          final DocumentReference<Map<String, dynamic>> movementRef = _movements
              .doc();
          tx.set(
            movementRef,
            StockMovementModel(
              id: movementRef.id,
              productId: product.id,
              type: StockMovementType.sale,
              quantity: qty,
              date: now,
              userId: profile.uid,
            ).toMap(),
          );
        }

        sale = SaleModel(
          id: saleRef.id,
          items: items,
          totalAmount: SaleModel.calculateTotal(items),
          date: now,
          userId: profile.uid,
        );
        tx.set(saleRef, sale.toMap());
      });

      return sale;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Latest sales, newest first.
  Stream<List<SaleModel>> streamRecentSales({int limit = 20}) {
    return _sales
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map(_toSales);
  }

  /// Sales made since midnight today (device time zone).
  Stream<List<SaleModel>> streamTodaySales() {
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    return _sales
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .snapshots()
        .map(_toSales);
  }

  // ---------- Helpers used by the UI ----------

  /// Live total for the Record Sale dialog: sum of price x quantity.
  static double calculateTotal(
    List<SaleLineRequest> lines,
    List<ProductModel> products,
  ) {
    double total = 0;
    for (final SaleLineRequest line in lines) {
      for (final ProductModel product in products) {
        if (product.id == line.productId) {
          total += product.price * line.quantity;
          break;
        }
      }
    }
    return total;
  }

  /// "Today's Sales" card value.
  static double todayTotal(List<SaleModel> sales) {
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    double total = 0;
    for (final SaleModel sale in sales) {
      if (!sale.date.isBefore(startOfToday)) {
        total += sale.totalAmount;
      }
    }
    return total;
  }

  static List<SaleModel> _toSales(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              SaleModel.fromMap(doc.data(), doc.id),
        )
        .toList();
  }
}
