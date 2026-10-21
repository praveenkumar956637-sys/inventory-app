import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_import_row.dart';
import 'auth_service.dart';
import 'excel_service.dart';

class _Existing {
  const _Existing(this.id, this.name);

  final String id;
  final String name;
}

class _Operation {
  const _Operation({required this.row, this.existingId});

  final ProductImportRow row;

  /// null means "add a new product", otherwise "update this product".
  final String? existingId;
}

/// Checks imported rows against the products already in Firestore and saves
/// them. Admin only. Writes use the existing field names of the products
/// collection.
class ProductImportService {
  ProductImportService({FirebaseFirestore? firestore, AuthService? authService})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = authService ?? AuthService();

  final FirebaseFirestore _db;
  final AuthService _auth;

  // Kept at 20 so each batch stays within Firestore's limit on security-rule
  // lookups per request.
  static const int _batchSize = 20;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  /// Marks every row whose code already exists in Firestore.
  Future<List<ProductImportRow>> markExisting(
    List<ProductImportRow> rows,
  ) async {
    try {
      await _auth.requireAdmin();
      final Map<String, _Existing> existing = await _loadExisting();
      return rows.map((ProductImportRow row) {
        final _Existing? found = existing[ExcelService.codeKey(row.code)];
        if (found == null) return row.withExisting();
        return row.withExisting(id: found.id, name: found.name);
      }).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Saves the valid rows.
  /// - A new code is added as a new product.
  /// - A code that already exists is skipped, unless [updateExisting] is true.
  ///   Then the six imported fields of that product are overwritten
  ///   (the image link is left alone).
  /// Invalid rows are never saved.
  Future<ImportResult> commit(
    List<ProductImportRow> rows, {
    required bool updateExisting,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      await _auth.requireAdmin();

      // Look again, in case products changed since the preview.
      final Map<String, _Existing> existing = await _loadExisting();

      int invalid = 0;
      int skipped = 0;
      final List<_Operation> operations = <_Operation>[];

      for (final ProductImportRow row in rows) {
        if (!row.isValid) {
          invalid++;
          continue;
        }
        final _Existing? found = existing[ExcelService.codeKey(row.code)];
        if (found == null) {
          operations.add(_Operation(row: row));
        } else if (updateExisting) {
          operations.add(_Operation(row: row, existingId: found.id));
        } else {
          skipped++;
        }
      }

      int added = 0;
      int updated = 0;
      final List<ImportFailure> failures = <ImportFailure>[];

      for (int start = 0; start < operations.length; start += _batchSize) {
        final int end = min(start + _batchSize, operations.length);
        final List<_Operation> chunk = operations.sublist(start, end);

        final WriteBatch batch = _db.batch();
        for (final _Operation op in chunk) {
          if (op.existingId == null) {
            batch.set(_products.doc(), op.row.toMap());
          } else {
            batch.update(_products.doc(op.existingId!), op.row.toMap());
          }
        }

        try {
          await batch.commit();
          for (final _Operation op in chunk) {
            if (op.existingId == null) {
              added++;
            } else {
              updated++;
            }
          }
        } catch (e) {
          final String message = AppException.messageOf(e);
          for (final _Operation op in chunk) {
            failures.add(
              ImportFailure(
                rowNumber: op.row.rowNumber,
                code: op.row.code,
                message: message,
              ),
            );
          }
        }

        onProgress?.call(end, operations.length);
      }

      return ImportResult(
        added: added,
        updated: updated,
        skippedDuplicates: skipped,
        invalid: invalid,
        failures: failures,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Map<String, _Existing>> _loadExisting() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _products.get();
    final Map<String, _Existing> map = <String, _Existing>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String code = (data['code'] as String?) ?? '';
      if (code.trim().isEmpty) continue;
      map[ExcelService.codeKey(code)] = _Existing(
        doc.id,
        (data['name'] as String?) ?? '',
      );
    }
    return map;
  }
}
