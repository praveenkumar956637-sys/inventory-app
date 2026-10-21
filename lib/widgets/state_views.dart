import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Centered spinner for loading states.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Icon, title and optional message for empty lists and empty search results.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 72,
              width: 72,
              decoration: const BoxDecoration(
                color: AppColors.blackTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.darkBlack),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error message with a Retry button and an optional Logout button.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 72,
              width: 72,
              decoration: const BoxDecoration(
                color: AppColors.redTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 34,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(160, 46)),
            ),
            if (onLogout != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(onPressed: onLogout, child: const Text('Logout')),
            ],
          ],
        ),
      ),
    );
  }
}
