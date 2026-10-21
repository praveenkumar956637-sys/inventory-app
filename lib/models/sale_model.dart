import 'package:cloud_firestore/cloud_firestore.dart';

/// One line of a sale. Name and price are copied at the time of sale,
/// so later price changes do not alter old sales.
class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  double get lineTotal => price * quantity;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: (map['productId'] as String?) ?? '',
      productName: (map['productName'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }
}

class SaleModel {
  final String id;
  final List<SaleItem> items;
  final double totalAmount;
  final DateTime date;
  final String userId;

  const SaleModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.date,
    required this.userId,
  });

  /// Sum of all item line totals. SaleService uses this to build totalAmount.
  static double calculateTotal(List<SaleItem> items) {
    double total = 0;
    for (final SaleItem item in items) {
      total += item.lineTotal;
    }
    return total;
  }

  factory SaleModel.fromMap(Map<String, dynamic> map, String id) {
    final dynamic rawItems = map['items'];
    final List<SaleItem> parsedItems = <SaleItem>[];
    if (rawItems is List) {
      for (final dynamic raw in rawItems) {
        if (raw is Map) {
          parsedItems.add(SaleItem.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final dynamic rawDate = map['date'];
    return SaleModel(
      id: id,
      items: parsedItems,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      date: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      userId: (map['userId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'items': items.map((SaleItem item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'userId': userId,
    };
  }
}
