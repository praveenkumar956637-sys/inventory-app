import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../core/utils/formatters.dart';
import '../models/product_import_row.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import 'auth_service.dart';

/// Result of reading an Excel file.
class ParsedImport {
  const ParsedImport({required this.sheetName, required this.rows});

  final String sheetName;
  final List<ProductImportRow> rows;
}

/// Builds Excel files from data and reads product rows from Excel files.
/// It does not touch Firestore, files or the network.
class ExcelService {
  ExcelService._();

  static const int maxImportRows = 2000;

  static const List<String> importHeaders = <String>[
    'Name',
    'Code',
    'Category',
    'Quantity',
    'Price',
    'Minimum Stock',
  ];

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  static Uint8List inventoryReport(List<ProductModel> products) {
    final Excel excel = Excel.createExcel();
    final Sheet sheet = _prepare(excel, 'Inventory', importHeaders, <double>[
      28,
      16,
      22,
      12,
      14,
      16,
    ]);
    for (final ProductModel p in products) {
      sheet.appendRow(<CellValue>[
        TextCellValue(p.name),
        TextCellValue(p.code),
        TextCellValue(p.category),
        IntCellValue(p.quantity),
        DoubleCellValue(p.price),
        IntCellValue(p.minimumStock),
      ]);
    }
    return _toBytes(excel);
  }

  static Uint8List lowStockReport(List<ProductModel> products) {
    final Excel excel = Excel.createExcel();
    final Sheet sheet = _prepare(
      excel,
      'Low Stock',
      <String>[...importHeaders, 'Status'],
      <double>[28, 16, 22, 12, 14, 16, 16],
    );
    for (final ProductModel p in products) {
      sheet.appendRow(<CellValue>[
        TextCellValue(p.name),
        TextCellValue(p.code),
        TextCellValue(p.category),
        IntCellValue(p.quantity),
        DoubleCellValue(p.price),
        IntCellValue(p.minimumStock),
        TextCellValue(p.statusLabel),
      ]);
    }
    return _toBytes(excel);
  }

  static Uint8List salesReport(
    List<SaleModel> sales,
    Map<String, String> userNames,
  ) {
    final Excel excel = Excel.createExcel();
    final Sheet sheet = _prepare(
      excel,
      'Sales',
      <String>[
        'Date',
        'Time',
        'Items',
        'Total Quantity',
        'Total Amount (₹)',
        'Sold By',
      ],
      <double>[14, 12, 50, 16, 18, 22],
    );
    for (final SaleModel sale in sales) {
      final String items = sale.items
          .map((SaleItem i) => '${i.productName} × ${i.quantity}')
          .join(', ');
      final int totalQuantity = sale.items.fold<int>(
        0,
        (int sum, SaleItem i) => sum + i.quantity,
      );
      sheet.appendRow(<CellValue>[
        TextCellValue(Formatters.date(sale.date)),
        TextCellValue(Formatters.time(sale.date)),
        TextCellValue(items),
        IntCellValue(totalQuantity),
        DoubleCellValue(sale.totalAmount),
        TextCellValue(userNames[sale.userId] ?? 'Unknown'),
      ]);
    }
    return _toBytes(excel);
  }

  static Uint8List stockMovementReport(
    List<StockMovementModel> movements,
    Map<String, String> productNames,
    Map<String, String> userNames,
  ) {
    final Excel excel = Excel.createExcel();
    final Sheet sheet = _prepare(
      excel,
      'Stock Movements',
      <String>['Date', 'Time', 'Type', 'Product', 'Quantity', 'User'],
      <double>[14, 12, 14, 30, 12, 22],
    );
    for (final StockMovementModel m in movements) {
      sheet.appendRow(<CellValue>[
        TextCellValue(Formatters.date(m.date)),
        TextCellValue(Formatters.time(m.date)),
        TextCellValue(m.type),
        TextCellValue(productNames[m.productId] ?? 'Deleted product'),
        IntCellValue(m.quantity),
        TextCellValue(userNames[m.userId] ?? 'Unknown'),
      ]);
    }
    return _toBytes(excel);
  }

  /// Empty import file: headers only, plus a sheet of instructions.
  /// It contains no sample products.
  static Uint8List importTemplate() {
    final Excel excel = Excel.createExcel();
    _prepare(excel, 'Products', importHeaders, <double>[
      28,
      16,
      22,
      12,
      14,
      16,
    ]);

    final Sheet help = excel['Instructions'];
    final List<String> lines = <String>[
      'How to fill the Products sheet',
      'Keep the headers in row 1 of the Products sheet.',
      'Name, Code and Category are required text.',
      'Code must be unique. A code that already exists in the app is skipped unless you choose to update existing products.',
      'Quantity and Minimum Stock must be whole numbers, 0 or more.',
      'Price must be a number, 0 or more.',
      'Save the file as Excel Workbook (.xlsx). Old .xls files are not supported.',
    ];
    for (final String line in lines) {
      help.appendRow(<CellValue>[TextCellValue(line)]);
    }
    help
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
    );
    help.setColumnWidth(0, 110);

    return _toBytes(excel);
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  static const List<String> _requiredFields = <String>[
    'name',
    'code',
    'category',
    'quantity',
    'price',
    'minimumStock',
  ];

  static const Map<String, String> _fieldLabels = <String, String>{
    'name': 'Name',
    'code': 'Code',
    'category': 'Category',
    'quantity': 'Quantity',
    'price': 'Price',
    'minimumStock': 'Minimum Stock',
  };

  /// Header text (lowercase, letters and digits only) -> field.
  static const Map<String, String> _aliases = <String, String>{
    'name': 'name',
    'productname': 'name',
    'itemname': 'name',
    'product': 'name',
    'code': 'code',
    'productcode': 'code',
    'itemcode': 'code',
    'sku': 'code',
    'category': 'category',
    'quantity': 'quantity',
    'qty': 'quantity',
    'price': 'price',
    'unitprice': 'price',
    'minimumstock': 'minimumStock',
    'minstock': 'minimumStock',
    'minimumquantity': 'minimumStock',
    'reorderlevel': 'minimumStock',
  };

  /// Reads product rows from an .xlsx file.
  /// Throws [AppException] when the file cannot be read or has no usable rows.
  static ParsedImport parseProducts(Uint8List bytes) {
    _checkFileType(bytes);
    final Excel excel = _decode(bytes);

    if (excel.tables.isEmpty) {
      throw const AppException('The Excel file has no sheets.');
    }
    final String sheetName = excel.tables.keys.first;
    final Sheet? sheet = excel.tables[sheetName];
    if (sheet == null) {
      throw const AppException('The first sheet of the file cannot be read.');
    }
    final List<List<Data?>> rows = sheet.rows;

    // The header is the first row that has any text.
    int headerIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].any((Data? c) => _cellText(c).isNotEmpty)) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex < 0) {
      throw const AppException('The Excel file is empty.');
    }

    final Map<String, int> columns = <String, int>{};
    final List<Data?> headerRow = rows[headerIndex];
    for (int c = 0; c < headerRow.length; c++) {
      final String? field = _aliases[_normalize(_cellText(headerRow[c]))];
      if (field != null && !columns.containsKey(field)) {
        columns[field] = c;
      }
    }

    final List<String> missing = _requiredFields
        .where((String f) => !columns.containsKey(f))
        .map((String f) => _fieldLabels[f] ?? f)
        .toList();
    if (missing.isNotEmpty) {
      throw AppException(
        'Missing column: ${missing.join(', ')}. '
        'The first row must have these headers: ${importHeaders.join(', ')}.',
      );
    }

    final List<ProductImportRow> result = <ProductImportRow>[];
    final Map<String, int> seenCodes = <String, int>{};

    for (int r = headerIndex + 1; r < rows.length; r++) {
      final List<Data?> row = rows[r];

      String cell(String field) {
        final int? col = columns[field];
        if (col == null || col >= row.length) return '';
        return _cellText(row[col]);
      }

      final String name = cell('name');
      final String code = cell('code');
      final String category = cell('category');
      final String quantityText = cell('quantity');
      final String priceText = cell('price');
      final String minimumText = cell('minimumStock');

      final bool blank = <String>[
        name,
        code,
        category,
        quantityText,
        priceText,
        minimumText,
      ].every((String s) => s.isEmpty);
      if (blank) continue;

      if (result.length >= maxImportRows) {
        throw const AppException(
          'The file has more than $maxImportRows product rows. '
          'Please split it into smaller files.',
        );
      }

      final List<String> errors = <String>[];
      if (name.isEmpty) errors.add('Product name is missing.');
      if (code.isEmpty) errors.add('Product code is missing.');
      if (category.isEmpty) errors.add('Category is missing.');

      final int? quantity = _parseWholeNumber(quantityText);
      if (quantity == null || quantity < 0) {
        errors.add('Quantity must be a whole number (0 or more).');
      }

      final double? price = _parsePrice(priceText);
      if (price == null || price < 0) {
        errors.add('Price must be a number (0 or more).');
      }

      final int? minimumStock = _parseWholeNumber(minimumText);
      if (minimumStock == null || minimumStock < 0) {
        errors.add('Minimum stock must be a whole number (0 or more).');
      }

      if (code.isNotEmpty) {
        final String key = codeKey(code);
        final int? firstRow = seenCodes[key];
        if (firstRow != null) {
          errors.add(
            'Duplicate code "$code" (already used in row $firstRow of this file).',
          );
        } else {
          seenCodes[key] = r + 1;
        }
      }

      result.add(
        ProductImportRow(
          rowNumber: r + 1,
          name: name,
          code: code,
          category: category,
          quantity: quantity != null && quantity >= 0 ? quantity : null,
          price: price != null && price >= 0 ? price : null,
          minimumStock: minimumStock != null && minimumStock >= 0
              ? minimumStock
              : null,
          errors: errors,
        ),
      );
    }

    if (result.isEmpty) {
      throw const AppException('No product rows were found in the file.');
    }
    return ParsedImport(sheetName: sheetName, rows: result);
  }

  /// Key used to compare product codes (ignores capitals and spaces).
  static String codeKey(String code) => code.trim().toLowerCase();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Renames the default sheet, writes a bold header row and sets widths.
  static Sheet _prepare(
    Excel excel,
    String title,
    List<String> headers,
    List<double> widths,
  ) {
    excel.rename('Sheet1', title);
    final Sheet sheet = excel[title];

    sheet.appendRow(headers.map((String h) => TextCellValue(h)).toList());
    for (int i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
      );
      if (i < widths.length) {
        sheet.setColumnWidth(i, widths[i]);
      }
    }
    return sheet;
  }

  static Uint8List _toBytes(Excel excel) {
    final List<int>? data = excel.encode();
    if (data == null) {
      throw const AppException(
        'Could not create the Excel file. Please try again.',
      );
    }
    return Uint8List.fromList(data);
  }

  static void _checkFileType(Uint8List bytes) {
    // Old .xls files start with D0 CF 11 E0.
    if (bytes.length >= 4 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      throw const AppException(
        'Old .xls files are not supported. Open the file in Excel and use '
        'Save As, Excel Workbook (.xlsx), then import that file.',
      );
    }
    // .xlsx files are zip files that start with "PK".
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const AppException(
        'This is not a valid .xlsx file. Please choose an Excel Workbook.',
      );
    }
  }

  static Excel _decode(Uint8List bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (_) {
      throw const AppException(
        'The Excel file could not be read. It may be damaged or protected '
        'with a password.',
      );
    }
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _cellText(Data? cell) {
    final CellValue? value = cell?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString().trim();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final double d = value.value;
      if (d.isFinite && d == d.roundToDouble()) {
        return d.toInt().toString();
      }
      return d.toString();
    }
    return value.toString().trim();
  }

  static int? _parseWholeNumber(String text) {
    final String t = text.replaceAll(',', '').trim();
    if (t.isEmpty) return null;
    final int? whole = int.tryParse(t);
    if (whole != null) return whole;
    final double? d = double.tryParse(t);
    if (d != null && d.isFinite && d == d.roundToDouble()) {
      return d.toInt();
    }
    return null;
  }

  static double? _parsePrice(String text) {
    final String t = text
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\s'), '')
        .trim();
    if (t.isEmpty) return null;
    final double? d = double.tryParse(t);
    if (d == null || !d.isFinite) return null;
    return d;
  }
}
