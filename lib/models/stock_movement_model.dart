import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovementType {
  StockMovementType._();

  static const String stockIn = 'Stock In';
  static const String stockOut = 'Stock Out';
  static const String sale = 'Sale';
}

class StockMovementModel {
  final String id;
  final String productId;
  final String type;
  final int quantity;
  final DateTime date;
  final String userId;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
    required this.userId,
  });

  factory StockMovementModel.fromMap(Map<String, dynamic> map, String id) {
    final dynamic rawDate = map['date'];
    return StockMovementModel(
      id: id,
      productId: (map['productId'] as String?) ?? '',
      type: (map['type'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      date: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      userId: (map['userId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'type': type,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
      'userId': userId,
    };
  }
}
