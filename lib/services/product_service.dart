import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import 'auth_service.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore, AuthService? authService})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = authService ?? AuthService();

  final FirebaseFirestore _db;
  final AuthService _auth;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  /// Live list of all products, sorted by name.
  Stream<List<ProductModel>> streamProducts() {
    return _products.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
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
    });
  }

  /// Admin only.
  Future<void> addProduct({
    required String name,
    required String code,
    required String category,
    required int quantity,
    required double price,
    required int minimumStock,
    String imageUrl = '',
  }) async {
    try {
      await _auth.requireAdmin();
      final String cleanName = name.trim();
      final String cleanCode = code.trim();
      final String cleanCategory = category.trim();
      final String cleanImage = imageUrl.trim();
      _validate(
        name: cleanName,
        code: cleanCode,
        category: cleanCategory,
        quantity: quantity,
        price: price,
        minimumStock: minimumStock,
        imageUrl: cleanImage,
      );
      await _ensureCodeUnique(cleanCode);

      final ProductModel product = ProductModel(
        id: '',
        name: cleanName,
        code: cleanCode,
        category: cleanCategory,
        quantity: quantity,
        price: price,
        minimumStock: minimumStock,
        imageUrl: cleanImage,
      );
      await _products.add(product.toMap());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin only.
  Future<void> updateProduct(ProductModel product) async {
    try {
      await _auth.requireAdmin();
      if (product.id.isEmpty) {
        throw const AppException('Product not found.');
      }
      final ProductModel clean = product.copyWith(
        name: product.name.trim(),
        code: product.code.trim(),
        category: product.category.trim(),
        imageUrl: product.imageUrl.trim(),
      );
      _validate(
        name: clean.name,
        code: clean.code,
        category: clean.category,
        quantity: clean.quantity,
        price: clean.price,
        minimumStock: clean.minimumStock,
        imageUrl: clean.imageUrl,
      );
      await _ensureCodeUnique(clean.code, excludeId: clean.id);

      final Map<String, dynamic> data = clean.toMap();
      // An empty image removes the stored field.
      if (clean.imageUrl.isEmpty) {
        data['imageUrl'] = FieldValue.delete();
      }
      await _products.doc(clean.id).update(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin only. Old stock movements stay in the database;
  /// the UI should show "Deleted product" for them.
  Future<void> deleteProduct(String productId) async {
    try {
      await _auth.requireAdmin();
      if (productId.isEmpty) {
        throw const AppException('Product not found.');
      }
      await _products.doc(productId).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ---------- Helpers used by the dashboards ----------

  /// Search by name, code or category.
  static List<ProductModel> filter(List<ProductModel> products, String query) {
    return products.where((ProductModel p) => p.matchesSearch(query)).toList();
  }

  /// Products that are Low Stock or Out of Stock.
  static List<ProductModel> lowStockProducts(List<ProductModel> products) {
    return products.where((ProductModel p) => p.isLowOrOut).toList();
  }

  /// Sum of all quantities ("Available Stock" card).
  static int totalQuantity(List<ProductModel> products) {
    int total = 0;
    for (final ProductModel p in products) {
      total += p.quantity;
    }
    return total;
  }

  // ---------- Private ----------

  void _validate({
    required String name,
    required String code,
    required String category,
    required int quantity,
    required double price,
    required int minimumStock,
    required String imageUrl,
  }) {
    if (name.isEmpty) {
      throw const AppException('Product name is required.');
    }
    if (code.isEmpty) {
      throw const AppException('Product code is required.');
    }
    if (category.isEmpty) {
      throw const AppException('Category is required.');
    }
    if (quantity < 0) {
      throw const AppException('Quantity cannot be negative.');
    }
    if (price < 0) {
      throw const AppException('Price cannot be negative.');
    }
    if (minimumStock < 0) {
      throw const AppException('Minimum stock cannot be negative.');
    }
    if (imageUrl.length > 500) {
      throw const AppException('Image link is too long.');
    }
  }

  Future<void> _ensureCodeUnique(String code, {String? excludeId}) async {
    final QuerySnapshot<Map<String, dynamic>> result = await _products
        .where('code', isEqualTo: code)
        .limit(2)
        .get();
    final bool clash = result.docs.any(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id != excludeId,
    );
    if (clash) {
      throw AppException('A product with code "$code" already exists.');
    }
  }
}
