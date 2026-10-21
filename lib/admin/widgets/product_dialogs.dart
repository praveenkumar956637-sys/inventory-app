import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../widgets/app_dialog.dart';

/// Opens the Add Product dialog (product == null) or the Edit Product dialog.
/// Returns a success message when saved, or null when cancelled.
Future<String?> showProductFormDialog(
  BuildContext context, {
  ProductModel? product,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _ProductFormDialog(product: product);
    },
  );
}

/// Asks "Are you sure you want to delete this product?".
/// Returns true only when the admin presses Delete.
Future<bool> confirmDeleteProduct(
  BuildContext context,
  ProductModel product,
) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        icon: Icons.delete_outline,
        title: 'Delete Product',
        confirmLabel: 'Delete',
        onConfirm: () => Navigator.of(dialogContext).pop(true),
        onCancel: () => Navigator.of(dialogContext).pop(false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Are you sure you want to delete this product?',
              style: TextStyle(fontSize: 15, color: AppColors.darkBlack),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.darkBlack,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  final ProductModel? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final ProductService _service = ProductService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _codeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _minimumController;
  late final TextEditingController _imageController;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final ProductModel? p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _codeController = TextEditingController(text: p?.code ?? '');
    _quantityController = TextEditingController(
      text: p == null ? '' : p.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: p == null ? '' : _formatPrice(p.price),
    );
    _minimumController = TextEditingController(
      text: p == null ? '' : p.minimumStock.toString(),
    );
    _imageController = TextEditingController(text: p?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _codeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _minimumController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price % 1 == 0 ? price.toStringAsFixed(0) : price.toString();
  }

  String? _validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _validateWholeNumber(String? value, String label) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return '$label is required.';
    final int? number = int.tryParse(text);
    if (number == null || number < 0) return 'Enter a valid number.';
    return null;
  }

  String? _validatePrice(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Price is required.';
    final double? number = double.tryParse(text);
    if (number == null || number < 0) return 'Enter a valid price.';
    return null;
  }

  /// Optional. A link (https://...) or an asset path (assets/...).
  String? _validateImage(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length > 500) return 'Image link is too long.';
    final bool ok =
        text.startsWith('https://') ||
        text.startsWith('http://') ||
        text.startsWith('assets/');
    if (!ok) {
      return 'Start with https:// or assets/';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final String name = _nameController.text.trim();
      final String category = _categoryController.text.trim();
      final String code = _codeController.text.trim();
      final int quantity = int.parse(_quantityController.text.trim());
      final double price = double.parse(_priceController.text.trim());
      final int minimumStock = int.parse(_minimumController.text.trim());
      final String imageUrl = _imageController.text.trim();

      if (_isEdit) {
        await _service.updateProduct(
          widget.product!.copyWith(
            name: name,
            category: category,
            code: code,
            quantity: quantity,
            price: price,
            minimumStock: minimumStock,
            imageUrl: imageUrl,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop('Product updated successfully.');
      } else {
        await _service.addProduct(
          name: name,
          code: code,
          category: category,
          quantity: quantity,
          price: price,
          minimumStock: minimumStock,
          imageUrl: imageUrl,
        );
        if (!mounted) return;
        Navigator.of(context).pop('Product added successfully.');
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
    return AppDialog(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
      title: _isEdit ? 'Edit Product' : 'Add Product',
      loading: _saving,
      confirmLabel: _isEdit ? 'Update' : 'Save',
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
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (String? v) => _validateRequired(v, 'Product name'),
              decoration: AppTheme.inputDecoration(
                label: 'Product name',
                prefixIcon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoryController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (String? v) => _validateRequired(v, 'Category'),
              decoration: AppTheme.inputDecoration(
                label: 'Category',
                prefixIcon: Icons.category_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _codeController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              validator: (String? v) => _validateRequired(v, 'Product code'),
              decoration: AppTheme.inputDecoration(
                label: 'Product code',
                prefixIcon: Icons.qr_code_2,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    validator: (String? v) =>
                        _validateWholeNumber(v, 'Quantity'),
                    decoration: AppTheme.inputDecoration(label: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minimumController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    validator: (String? v) =>
                        _validateWholeNumber(v, 'Minimum stock'),
                    decoration: AppTheme.inputDecoration(
                      label: 'Minimum stock',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                LengthLimitingTextInputFormatter(10),
              ],
              validator: _validatePrice,
              decoration: AppTheme.inputDecoration(
                label: 'Price (₹)',
                prefixIcon: Icons.currency_rupee,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _imageController,
              enabled: !_saving,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              validator: _validateImage,
              onFieldSubmitted: (_) => _submit(),
              decoration: AppTheme.inputDecoration(
                label: 'Image (optional)',
                hint: 'https://... or assets/images/cement.png',
                prefixIcon: Icons.image_outlined,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
