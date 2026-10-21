import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Shared dialog frame: icon + title on top, scrolling body, two buttons below.
/// While [loading] is true the main button shows a spinner, all buttons are
/// locked, and the dialog cannot be closed with Back.
/// When [confirmLabel] is null only a single close button is shown.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor = AppColors.primaryRed,
    this.iconTint = AppColors.redTint,
    this.confirmLabel,
    this.onConfirm,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.confirmColor,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color iconColor;
  final Color iconTint;
  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final Color? confirmColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !loading,
      child: Dialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: <Widget>[
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: iconTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: child,
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: loading
                            ? null
                            : (onCancel ?? () => Navigator.of(context).pop()),
                        child: Text(cancelLabel),
                      ),
                    ),
                    if (confirmLabel != null) ...<Widget>[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          // While loading the tap is ignored, but the button
                          // keeps its normal color so the spinner stays clear.
                          onPressed: loading ? () {} : onConfirm,
                          style: confirmColor == null
                              ? null
                              : ElevatedButton.styleFrom(
                                  backgroundColor: confirmColor,
                                ),
                          child: loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.white,
                                  ),
                                )
                              : Text(confirmLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red message box shown at the top of a dialog when saving fails.
class DialogErrorBox extends StatelessWidget {
  const DialogErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryRed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            color: AppColors.primaryRed,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.darkBlack),
            ),
          ),
        ],
      ),
    );
  }
}
