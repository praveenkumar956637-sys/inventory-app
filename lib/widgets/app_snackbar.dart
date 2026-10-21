import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Green message with a check icon, for successful operations.
void showSuccessSnackBar(BuildContext context, String message) {
  _show(context, message, AppColors.green, Icons.check_circle_outline);
}

/// Red message with a warning icon, for errors.
void showErrorSnackBar(BuildContext context, String message) {
  _show(context, message, AppColors.primaryRed, Icons.error_outline);
}

void _show(BuildContext context, String message, Color color, IconData icon) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
}
