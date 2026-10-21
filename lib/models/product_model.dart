enum StockStatus { inStock, lowStock, outOfStock }

class ProductModel {
  final String id;
  final String name;
  final String code;
  final String category;
  final int quantity;
  final double price;
  final int minimumStock;

  /// Optional: an https link, or an asset path like assets/images/cement.png.
  final String imageUrl;

  const ProductModel({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.quantity,
    required this.price,
    required this.minimumStock,
    this.imageUrl = '',
  });

  /// Out of Stock when quantity is 0, Low Stock when quantity <= minimumStock,
  /// otherwise In Stock.
  StockStatus get status {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= minimumStock) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  String get statusLabel {
    switch (status) {
      case StockStatus.outOfStock:
        return 'Out of Stock';
      case StockStatus.lowStock:
        return 'Low Stock';
      case StockStatus.inStock:
        return 'In Stock';
    }
  }

  /// True for both Low Stock and Out of Stock (used for alerts and the bell count).
  bool get isLowOrOut => status != StockStatus.inStock;

  /// Case-insensitive match on name, code or category.
  bool matchesSearch(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q);
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      name: (map['name'] as String?) ?? '',
      code: (map['code'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (map['minimumStock'] as num?)?.toInt() ?? 0,
      imageUrl: (map['imageUrl'] as String?) ?? '',
    );
  }

  /// imageUrl is written only when it is not empty.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'code': code,
      'category': category,
      'quantity': quantity,
      'price': price,
      'minimumStock': minimumStock,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    };
  }

  ProductModel copyWith({
    String? name,
    String? code,
    String? category,
    int? quantity,
    double? price,
    int? minimumStock,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      minimumStock: minimumStock ?? this.minimumStock,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
