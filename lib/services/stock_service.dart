import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/stock_movement_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class StockService {
  StockService({FirebaseFirestore? firestore, AuthService? authService})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = authService ?? AuthService();

  final FirebaseFirestore _db;
  final AuthService _auth;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');

  /// newQuantity = oldQuantity + incoming. Allowed for Admin and Staff.
  Future<void> stockIn({required String productId, required int quantity}) {
    return _changeStock(
      productId: productId,
      quantity: quantity,
      type: StockMovementType.stockIn,
    );
  }

  /// newQuantity = oldQuantity - outgoing. Fails with "Insufficient stock"
  /// when outgoing is more than available. Allowed for Admin and Staff.
  Future<void> stockOut({required String productId, required int quantity}) {
    return _changeStock(
      productId: productId,
      quantity: quantity,
      type: StockMovementType.stockOut,
    );
  }

  /// Latest stock movements (Stock In, Stock Out and Sale), newest first.
  Stream<List<StockMovementModel>> streamRecentMovements({int limit = 20}) {
    return _movements
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    StockMovementModel.fromMap(doc.data(), doc.id),
              )
              .toList();
        });
  }

  Future<void> _changeStock({
    required String productId,
    required int quantity,
    required String type,
  }) async {
    try {
      final UserModel profile = await _auth.requireActiveUser();

      if (productId.isEmpty) {
        throw const AppException('Please select a product.');
      }
      if (quantity <= 0) {
        throw const AppException('Quantity must be greater than zero.');
      }

      final DocumentReference<Map<String, dynamic>> productRef = _products.doc(
        productId,
      );
      final DocumentReference<Map<String, dynamic>> movementRef = _movements
          .doc();
      final bool isIn = type == StockMovementType.stockIn;

      // The quantity update and the movement record succeed or fail together.
      await _db.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(
          productRef,
        );
        final Map<String, dynamic>? data = snap.data();
        if (!snap.exists || data == null) {
          throw const AppException('Product not found.');
        }
        final ProductModel product = ProductModel.fromMap(data, snap.id);

        if (!isIn && quantity > product.quantity) {
          throw AppException(
            'Insufficient stock. Available: ${product.quantity}',
          );
        }

        final int newQuantity = isIn
            ? product.quantity + quantity
            : product.quantity - quantity;

        tx.update(productRef, <String, dynamic>{'quantity': newQuantity});
        tx.set(
          movementRef,
          StockMovementModel(
            id: movementRef.id,
            productId: productId,
            type: type,
            quantity: quantity,
            date: DateTime.now(),
            userId: profile.uid,
          ).toMap(),
        );
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
