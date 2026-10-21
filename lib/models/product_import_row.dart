/// One product row read from an Excel file, before it is saved.
class ProductImportRow {
  const ProductImportRow({
    required this.rowNumber,
    required this.name,
    required this.code,
    required this.category,
    this.quantity,
    this.price,
    this.minimumStock,
    this.errors = const <String>[],
    this.existingId,
    this.existingName,
  });

  /// Row number in the spreadsheet (what the user sees in Excel).
  final int rowNumber;
  final String name;
  final String code;
  final String category;
  final int? quantity;
  final double? price;
  final int? minimumStock;

  /// Problems found while reading the file. Empty means the row is valid.
  final List<String> errors;

  /// Set when a product with the same code already exists in Firestore.
  final String? existingId;
  final String? existingName;

  bool get isValid => errors.isEmpty;
  bool get isDuplicate => existingId != null;

  ProductImportRow withExisting({String? id, String? name}) {
    return ProductImportRow(
      rowNumber: rowNumber,
      name: this.name,
      code: code,
      category: category,
      quantity: quantity,
      price: price,
      minimumStock: minimumStock,
      errors: errors,
      existingId: id,
      existingName: name,
    );
  }

  /// Firestore fields. Only call this on a valid row.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'code': code,
      'category': category,
      'quantity': quantity ?? 0,
      'price': price ?? 0.0,
      'minimumStock': minimumStock ?? 0,
    };
  }
}

/// A row that could not be saved.
class ImportFailure {
  const ImportFailure({
    required this.rowNumber,
    required this.code,
    required this.message,
  });

  final int rowNumber;
  final String code;
  final String message;
}

/// What happened after pressing Import.
class ImportResult {
  const ImportResult({
    required this.added,
    required this.updated,
    required this.skippedDuplicates,
    required this.invalid,
    required this.failures,
  });

  final int added;
  final int updated;
  final int skippedDuplicates;

  /// Rows that had validation errors and were not imported.
  final int invalid;

  /// Valid rows that could not be saved because of a database error.
  final List<ImportFailure> failures;
}
