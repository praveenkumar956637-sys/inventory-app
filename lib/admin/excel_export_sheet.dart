import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/file_service.dart';
import '../services/report_service.dart';
import '../widgets/app_card.dart';

/// Bottom sheet: choose a report, then save or share the Excel file.
Future<void> showExportReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.lightGrey,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) => const _ExportSheet(),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  final ReportService _reports = ReportService();
  final FileService _files = const FileService();

  ReportType? _generating;
  GeneratedReport? _report;
  bool _busy = false;
  String? _error;
  String? _notice;

  Future<void> _generate(ReportType type) async {
    if (_generating != null) return;
    setState(() {
      _generating = type;
      _error = null;
      _notice = null;
    });
    try {
      final GeneratedReport report = await _reports.generate(type);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppException.messageOf(e));
    } finally {
      if (mounted) {
        setState(() => _generating = null);
      }
    }
  }

  Future<void> _save() async {
    final GeneratedReport? report = _report;
    if (report == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final bool saved = await _files.saveBytes(
        fileName: report.fileName,
        bytes: report.bytes,
      );
      if (!mounted) return;
      if (saved) {
        setState(() => _notice = kIsWeb ? 'Download started.' : 'File saved.');
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

  Future<void> _share(BuildContext buttonContext) async {
    final GeneratedReport? report = _report;
    if (report == null || _busy) return;

    // Anchor for the share sheet on iPad (ignored on phones).
    Rect? origin;
    final RenderObject? box = buttonContext.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final bool shared = await _files.shareBytes(
        fileName: report.fileName,
        bytes: report.bytes,
        title: report.fileName,
        origin: origin,
      );
      if (!mounted) return;
      if (shared) {
        setState(() => _notice = 'Report shared.');
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

  void _backToList() {
    setState(() {
      _report = null;
      _error = null;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 10),
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: <Widget>[
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.greenTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export Excel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final ReportType? generating = _generating;
    if (generating != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Preparing ${generating.title}...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.darkBlack),
            ),
          ],
        ),
      );
    }

    final GeneratedReport? report = _report;
    if (report != null) {
      return _buildReady(report);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error != null) ...<Widget>[
          _Banner(message: _error!, isError: true),
          const SizedBox(height: 12),
        ],
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Choose a report to export as an Excel (.xlsx) file.',
            style: TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
        ),
        for (final ReportType type in ReportType.values) _buildOption(type),
      ],
    );
  }

  Widget _buildOption(ReportType type) {
    final IconData icon;
    final Color color;
    final Color tint;
    switch (type) {
      case ReportType.inventory:
        icon = Icons.inventory_2_outlined;
        color = AppColors.darkBlack;
        tint = AppColors.blackTint;
      case ReportType.sales:
        icon = Icons.point_of_sale;
        color = AppColors.green;
        tint = AppColors.greenTint;
      case ReportType.stockMovements:
        icon = Icons.swap_vert;
        color = AppColors.darkBlack;
        tint = AppColors.blackTint;
      case ReportType.lowStock:
        icon = Icons.warning_amber_rounded;
        color = AppColors.primaryRed;
        tint = AppColors.redTint;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => _generate(type),
      child: Row(
        children: <Widget>[
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  type.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _buildReady(GeneratedReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_notice != null) ...<Widget>[
          _Banner(message: _notice!, isError: false),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...<Widget>[
          _Banner(message: _error!, isError: true),
          const SizedBox(height: 12),
        ],
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.greenTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Your file is ready',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.rowCount} ${report.rowCount == 1 ? 'row' : 'rows'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.save_alt),
          label: Text(kIsWeb ? 'Download' : 'Save to device'),
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (BuildContext buttonContext) {
            return OutlinedButton.icon(
              onPressed: _busy ? null : () => _share(buttonContext),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
            );
          },
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _busy ? null : _backToList,
          child: const Text('Choose another report'),
        ),
      ],
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
