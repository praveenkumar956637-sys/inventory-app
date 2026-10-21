import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../services/auth_service.dart';
import '../services/sale_service.dart';
import '../services/stock_service.dart';
import 'app_dialog.dart';

enum StockDialogMode { stockIn, stockOut }

/// Opens the Stock In or Stock Out dialog.
/// Returns a success message when saved, or null when cancelled.
Future<String?> showStockDialog(
  BuildContext context, {
  required StockDialogMode mode,
  required List<ProductModel> products,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _StockDialog(mode: mode, products: products);
    },
  );
}

/// Opens the Record Sale dialog.
/// Returns a success message when saved, or null when cancelled.
Future<String?> showRecordSaleDialog(
  BuildContext context, {
  required List<ProductModel> products,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _RecordSaleDialog(products: products);
    },
  );
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

List<DropdownMenuItem<String>> _productItems(List<ProductModel> products) {
  return products.map((ProductModel p) {
    return DropdownMenuItem<String>(
      value: p.id,
      child: Text(
        '${p.name} (Qty: ${p.quantity})',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }).toList();
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.darkBlack,
    this.bold = true,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stock In / Stock Out
// ---------------------------------------------------------------------------

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.mode, required this.products});

  final StockDialogMode mode;
  final List<ProductModel> products;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final StockService _service = StockService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _quantityKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController _quantityController = TextEditingController();

  String? _productId;
  bool _saving = false;
  String? _error;

  bool get _isIn => widget.mode == StockDialogMode.stockIn;

  ProductModel? get _selected {
    for (final ProductModel p in widget.products) {
      if (p.id == _productId) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String? _validateQuantity(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Quantity is required.';
    final int? number = int.tryParse(text);
    if (number == null || number <= 0) {
      return 'Enter a quantity greater than zero.';
    }
    final ProductModel? product = _selected;
    if (!_isIn && product != null && number > product.quantity) {
      return 'Insufficient stock. Available: ${product.quantity}';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    final ProductModel? product = _selected;
    if (product == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final int quantity = int.parse(_quantityController.text.trim());
      if (_isIn) {
        await _service.stockIn(productId: product.id, quantity: quantity);
        if (!mounted) return;
        Navigator.of(context).pop('Added $quantity to ${product.name}.');
      } else {
        await _service.stockOut(productId: product.id, quantity: quantity);
        if (!mounted) return;
        Navigator.of(context).pop('Removed $quantity from ${product.name}.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppException.messageOf(e));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = _isIn ? 'Stock In' : 'Stock Out';
    final IconData icon = _isIn
        ? Icons.add_circle_outline
        : Icons.remove_circle_outline;
    final Color color = _isIn ? AppColors.green : AppColors.primaryRed;
    final Color tint = _isIn ? AppColors.greenTint : AppColors.redTint;

    if (widget.products.isEmpty) {
      return AppDialog(
        icon: icon,
        iconColor: color,
        iconTint: tint,
        title: title,
        cancelLabel: 'Close',
        child: const Text(
          'No products available.',
          style: TextStyle(fontSize: 15, color: AppColors.darkBlack),
        ),
      );
    }

    final ProductModel? product = _selected;
    final int? entered = int.tryParse(_quantityController.text.trim());
    final bool showNewQuantity =
        product != null &&
        entered != null &&
        entered > 0 &&
        (_isIn || entered <= product.quantity);

    return AppDialog(
      icon: icon,
      iconColor: color,
      iconTint: tint,
      title: title,
      loading: _saving,
      confirmLabel: 'Confirm',
      confirmColor: color,
      onConfirm: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_error != null) ...<Widget>[
              DialogErrorBox(message: _error!),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              dropdownColor: AppColors.white,
              decoration: AppTheme.inputDecoration(
                label: 'Product',
                prefixIcon: Icons.inventory_2_outlined,
              ),
              hint: const Text('Select product'),
              items: _productItems(widget.products),
              onChanged: _saving
                  ? null
                  : (String? value) {
                      setState(() => _productId = value);
                      if (_quantityController.text.isNotEmpty) {
                        _quantityKey.currentState?.validate();
                      }
                    },
              validator: (String? value) =>
                  value == null ? 'Please select a product.' : null,
            ),
            if (product != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      label: 'Available quantity',
                      value: '${product.quantity}',
                      valueColor: product.quantity <= 0
                          ? AppColors.primaryRed
                          : AppColors.darkBlack,
                    ),
                    if (showNewQuantity) ...<Widget>[
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'New quantity',
                        value:
                            '${_isIn ? product.quantity + entered : product.quantity - entered}',
                        valueColor: AppColors.green,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              key: _quantityKey,
              controller: _quantityController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: _validateQuantity,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
              decoration: AppTheme.inputDecoration(
                label: _isIn ? 'Incoming quantity' : 'Outgoing quantity',
                prefixIcon: Icons.numbers,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Record Sale
// ---------------------------------------------------------------------------

class _SaleLineState {
  _SaleLineState(this.id);

  final int id;
  String? productId;
  final TextEditingController quantity = TextEditingController(text: '1');
}

class _RecordSaleDialog extends StatefulWidget {
  const _RecordSaleDialog({required this.products});

  final List<ProductModel> products;

  @override
  State<_RecordSaleDialog> createState() => _RecordSaleDialogState();
}

class _RecordSaleDialogState extends State<_RecordSaleDialog> {
  final SaleService _service = SaleService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<_SaleLineState> _lines = <_SaleLineState>[_SaleLineState(0)];
  int _nextId = 1;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final _SaleLineState line in _lines) {
      line.quantity.dispose();
    }
    super.dispose();
  }

  ProductModel? _find(String? id) {
    if (id == null) return null;
    for (final ProductModel p in widget.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  int _quantityOf(_SaleLineState line) {
    return int.tryParse(line.quantity.text.trim()) ?? 0;
  }

  /// Total quantity requested for one product across all lines.
  int _requestedFor(String productId) {
    int total = 0;
    for (final _SaleLineState line in _lines) {
      if (line.productId == productId) total += _quantityOf(line);
    }
    return total;
  }

  List<SaleLineRequest> _requests() {
    final List<SaleLineRequest> result = <SaleLineRequest>[];
    for (final _SaleLineState line in _lines) {
      final int qty = _quantityOf(line);
      if (line.productId != null && qty > 0) {
        result.add(SaleLineRequest(productId: line.productId!, quantity: qty));
      }
    }
    return result;
  }

  void _addLine() {
    setState(() => _lines.add(_SaleLineState(_nextId++)));
  }

  void _removeLine(_SaleLineState line) {
    setState(() => _lines.remove(line));
    // Dispose after the frame, when the removed field has left the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      line.quantity.dispose();
    });
  }

  String? _validateQuantity(_SaleLineState line, String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Quantity is required.';
    final int? number = int.tryParse(text);
    if (number == null || number <= 0) {
      return 'Enter a quantity greater than zero.';
    }
    final ProductModel? product = _find(line.productId);
    if (product != null && _requestedFor(product.id) > product.quantity) {
      return 'Insufficient stock. Available: ${product.quantity}';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final List<SaleLineRequest> requests = _requests();
    if (requests.isEmpty) {
      setState(() => _error = 'Add at least one product to the sale.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final SaleModel sale = await _service.recordSale(requests);
      if (!mounted) return;
      Navigator.of(context)
          .pop('Sale recorded. Total: ${Formatters.rupees(sale.totalAmount)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppException.messageOf(e));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const AppDialog(
        icon: Icons.point_of_sale,
        title: 'Record Sale',
        cancelLabel: 'Close',
        child: Text(
          'No products available.',
          style: TextStyle(fontSize: 15, color: AppColors.darkBlack),
        ),
      );
    }

    final List<SaleLineRequest> requests = _requests();
    final double total = SaleService.calculateTotal(requests, widget.products);

    return AppDialog(
      icon: Icons.point_of_sale,
      title: 'Record Sale',
      loading: _saving,
      confirmLabel: 'Record Sale',
      onConfirm: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_error != null) ...<Widget>[
              DialogErrorBox(message: _error!),
              const SizedBox(height: 12),
            ],
            for (int i = 0; i < _lines.length; i++) _buildLine(_lines[i]),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add another product'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.darkBlack,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.whiteSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${requests.length} ${requests.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.whiteSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Formatters.rupees(total),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(_SaleLineState line) {
    final ProductModel? product = _find(line.productId);
    final int qty = _quantityOf(line);

    return Container(
      key: ValueKey<String>('line-${line.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>('product-${line.id}'),
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            dropdownColor: AppColors.white,
            decoration: AppTheme.inputDecoration(
              label: 'Product',
              prefixIcon: Icons.inventory_2_outlined,
            ),
            hint: const Text('Select product'),
            items: _productItems(widget.products),
            onChanged: _saving
                ? null
                : (String? value) => setState(() => line.productId = value),
            validator: (String? value) =>
                value == null ? 'Please select a product.' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  key: ValueKey<String>('qty-${line.id}'),
                  controller: line.quantity,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  onChanged: (_) => setState(() {}),
                  validator: (String? value) => _validateQuantity(line, value),
                  decoration: AppTheme.inputDecoration(
                    label: 'Quantity',
                    prefixIcon: Icons.numbers,
                  ),
                ),
              ),
              if (_lines.length > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    tooltip: 'Remove',
                    onPressed: _saving ? null : () => _removeLine(line),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
            ],
          ),
          if (product != null) ...<Widget>[
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Available',
              value: '${product.quantity}',
              valueColor: product.quantity <= 0
                  ? AppColors.primaryRed
                  : AppColors.darkBlack,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Unit price',
              value: Formatters.rupees(product.price),
              bold: false,
            ),
            const SizedBox(height: 6),
            _InfoRow(label: 'Quantity', value: '$qty', bold: false),
            const Divider(height: 16),
            _InfoRow(
              label: 'Line total',
              value: Formatters.rupees(product.price * qty),
              valueColor: AppColors.green,
            ),
          ],
        ],
      ),
    );
  }
}
