import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/product_import_row.dart';
import '../services/auth_service.dart';
import '../services/excel_service.dart';
import '../services/file_service.dart';
import '../services/product_import_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/status_chip.dart';

enum _Step { pick, preview, importing, done }

class ExcelImportPage extends StatefulWidget {
  const ExcelImportPage({super.key});

  @override
  State<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  final FileService _files = const FileService();
  final ProductImportService _importService = ProductImportService();

  _Step _step = _Step.pick;
  bool _busy = false;
  String? _error;
  String _fileName = '';
  List<ProductImportRow> _rows = const <ProductImportRow>[];
  bool _updateExisting = false;
  int _done = 0;
  int _total = 0;
  ImportResult? _result;

  int get _errorCount => _rows.where((ProductImportRow r) => !r.isValid).length;
  int get _newCount =>
      _rows.where((ProductImportRow r) => r.isValid && !r.isDuplicate).length;
  int get _existingCount =>
      _rows.where((ProductImportRow r) => r.isValid && r.isDuplicate).length;
  int get _importCount => _newCount + (_updateExisting ? _existingCount : 0);

  Future<void> _chooseFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PickedExcel? picked = await _files.pickExcel();
      if (picked == null) return;

      final ParsedImport parsed = ExcelService.parseProducts(picked.bytes);
      final List<ProductImportRow> checked = await _importService.markExisting(
        parsed.rows,
      );
      if (!mounted) return;
      setState(() {
        _fileName = picked.name;
        _rows = checked;
        _updateExisting = false;
        _step = _Step.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppException.messageOf(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveTemplate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bool saved = await _files.saveBytes(
        fileName: 'product_import_template.xlsx',
        bytes: ExcelService.importTemplate(),
      );
      if (!mounted) return;
      if (saved) {
        showSuccessSnackBar(context, 'Template saved.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppException.messageOf(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _chooseAnother() {
    setState(() {
      _step = _Step.pick;
      _rows = const <ProductImportRow>[];
      _error = null;
      _result = null;
    });
  }

  Future<bool> _confirm() async {
    final int add = _newCount;
    final int update = _updateExisting ? _existingCount : 0;
    final int skip = _updateExisting ? 0 : _existingCount;
    final int errors = _errorCount;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          icon: Icons.upload_file,
          title: 'Import products',
          confirmLabel: 'Import',
          onConfirm: () => Navigator.of(dialogContext).pop(true),
          onCancel: () => Navigator.of(dialogContext).pop(false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Please confirm what will happen:',
                style: TextStyle(fontSize: 15, color: AppColors.darkBlack),
              ),
              const SizedBox(height: 12),
              if (add > 0)
                _DialogLine(
                  icon: Icons.add_circle_outline,
                  color: AppColors.green,
                  text: 'Add $add new ${add == 1 ? 'product' : 'products'}.',
                ),
              if (update > 0)
                _DialogLine(
                  icon: Icons.sync,
                  color: AppColors.primaryRed,
                  text:
                      'Update $update existing '
                      '${update == 1 ? 'product' : 'products'}. Their '
                      'category, quantity, price and minimum stock will be '
                      'replaced by the values in the file.',
                ),
              if (skip > 0)
                _DialogLine(
                  icon: Icons.skip_next_outlined,
                  color: AppColors.darkBlack,
                  text:
                      'Skip $skip ${skip == 1 ? 'product' : 'products'} '
                      'whose code already exists.',
                ),
              if (errors > 0)
                _DialogLine(
                  icon: Icons.error_outline,
                  color: AppColors.primaryRed,
                  text:
                      '$errors ${errors == 1 ? 'row has' : 'rows have'} '
                      'errors and will not be imported.',
                ),
            ],
          ),
        );
      },
    );
    return ok ?? false;
  }

  Future<void> _import() async {
    if (_importCount == 0) return;
    final bool confirmed = await _confirm();
    if (!confirmed || !mounted) return;

    setState(() {
      _step = _Step.importing;
      _done = 0;
      _total = _importCount;
      _error = null;
    });

    try {
      final ImportResult result = await _importService.commit(
        _rows,
        updateExisting: _updateExisting,
        onProgress: (int done, int total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppException.messageOf(e);
        _step = _Step.preview;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _Step.importing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Import Excel')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.pick:
        return _buildPick();
      case _Step.preview:
        return _buildPreview();
      case _Step.importing:
        return _buildImporting();
      case _Step.done:
        return _buildDone();
    }
  }

  // ---------------------------------------------------------------- pick

  Widget _buildPick() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            _Banner(message: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.redTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.upload_file,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Import products from Excel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Choose an .xlsx file. The first row must contain these '
                  'headers:',
                  style: TextStyle(fontSize: 14, color: AppColors.darkBlack),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExcelService.importHeaders
                      .map((String h) => _HeaderChip(label: h))
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You will see every row and any problems before anything '
                  'is saved. Products whose code already exists are skipped '
                  'unless you choose to update them. Old .xls files are not '
                  'supported; save them as .xlsx first.',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _chooseFile,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_busy ? 'Reading file...' : 'Choose Excel file'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _saveTemplate,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Download empty template'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- preview

  Widget _buildPreview() {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _rows.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) return _buildPreviewHeader();
              return _RowCard(
                row: _rows[index - 1],
                updateExisting: _updateExisting,
              );
            },
          ),
        ),
        _buildImportBar(),
      ],
    );
  }

  Widget _buildPreviewHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error != null) ...<Widget>[
          _Banner(message: _error!, isError: true),
          const SizedBox(height: 12),
        ],
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.table_chart_outlined,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _chooseAnother,
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat(
                      label: 'New',
                      value: _newCount,
                      color: AppColors.green,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Exist',
                      value: _existingCount,
                      color: AppColors.darkBlack,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Errors',
                      value: _errorCount,
                      color: _errorCount > 0
                          ? AppColors.primaryRed
                          : AppColors.darkBlack,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Rows',
                      value: _rows.length,
                      color: AppColors.darkBlack,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_existingCount > 0) ...<Widget>[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _updateExisting,
              onChanged: (bool value) {
                setState(() => _updateExisting = value);
              },
              title: const Text(
                'Update existing products',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBlack,
                ),
              ),
              subtitle: Text(
                _updateExisting
                    ? 'The $_existingCount products with a matching code will '
                          'be overwritten, including their quantity.'
                    : 'Off: the $_existingCount products with a matching '
                          'code are skipped.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _updateExisting
                      ? AppColors.primaryRed
                      : AppColors.textGrey,
                ),
              ),
            ),
          ),
        ],
        const SectionHeader(title: 'Preview'),
      ],
    );
  }

  Widget _buildImportBar() {
    final int count = _importCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: count == 0 ? null : _import,
          icon: const Icon(Icons.check),
          label: Text(
            count == 0
                ? 'Nothing to import'
                : 'Import $count ${count == 1 ? 'product' : 'products'}',
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- importing

  Widget _buildImporting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: AppColors.redTint,
              ),
              const SizedBox(height: 16),
              Text(
                'Saving $_done of $_total...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBlack,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please keep this screen open.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- done

  Widget _buildDone() {
    final ImportResult? result = _result;
    if (result == null) return const SizedBox.shrink();

    final bool hasFailures = result.failures.isNotEmpty;
    final Color color = hasFailures ? AppColors.primaryRed : AppColors.green;
    final Color tint = hasFailures ? AppColors.redTint : AppColors.greenTint;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasFailures
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasFailures
                      ? 'Import finished with problems'
                      : 'Import complete',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 16),
                _ResultRow(
                  label: 'Products added',
                  value: result.added,
                  color: AppColors.green,
                ),
                _ResultRow(
                  label: 'Products updated',
                  value: result.updated,
                  color: AppColors.darkBlack,
                ),
                _ResultRow(
                  label: 'Skipped (code already exists)',
                  value: result.skippedDuplicates,
                  color: AppColors.darkBlack,
                ),
                _ResultRow(
                  label: 'Not imported (errors in file)',
                  value: result.invalid,
                  color: result.invalid > 0
                      ? AppColors.primaryRed
                      : AppColors.darkBlack,
                ),
                _ResultRow(
                  label: 'Failed to save',
                  value: result.failures.length,
                  color: hasFailures
                      ? AppColors.primaryRed
                      : AppColors.darkBlack,
                ),
              ],
            ),
          ),
          if (hasFailures) ...<Widget>[
            const SectionHeader(title: 'Rows that could not be saved'),
            ...result.failures.map(
              (ImportFailure f) => AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Row ${f.rowNumber} • ${f.code}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _chooseAnother,
            child: const Text('Import another file'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.updateExisting});

  final ProductImportRow row;
  final bool updateExisting;

  @override
  Widget build(BuildContext context) {
    final StatusChip chip;
    if (!row.isValid) {
      chip = const StatusChip(
        label: 'Error',
        color: AppColors.primaryRed,
        tint: AppColors.redTint,
      );
    } else if (row.isDuplicate) {
      chip = StatusChip(
        label: updateExisting ? 'Will update' : 'Will skip',
        color: AppColors.darkBlack,
        tint: AppColors.blackTint,
      );
    } else {
      chip = const StatusChip(
        label: 'Ready',
        color: AppColors.green,
        tint: AppColors.greenTint,
      );
    }

    final String name = row.name.isEmpty ? '(no name)' : row.name;
    final String code = row.code.isEmpty ? '(no code)' : row.code;
    final String category = row.category.isEmpty
        ? '(no category)'
        : row.category;
    final String quantity = row.quantity?.toString() ?? '-';
    final String price = row.price == null
        ? '-'
        : Formatters.rupees(row.price!);
    final String minimum = row.minimumStock?.toString() ?? '-';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Row ${row.rowNumber}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$code • $category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chip,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Qty $quantity  •  $price  •  Min $minimum',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlack,
            ),
          ),
          if (row.isValid && row.isDuplicate) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Existing product: ${row.existingName ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
          for (final String error in row.errors) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 14,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.blackTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.darkBlack,
        ),
      ),
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.darkBlack),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color color = isError ? AppColors.primaryRed : AppColors.green;
    final Color tint = isError ? AppColors.redTint : AppColors.greenTint;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.darkBlack),
            ),
          ),
        ],
      ),
    );
  }
}
