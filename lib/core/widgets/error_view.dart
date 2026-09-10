import 'package:flutter/material.dart';
import '../utils/error_formatting.dart';
import 'app_button.dart';

/// Standard error placeholder with an optional retry action.
///
/// [message] is run through [friendlyErrorText] before display, so a
/// caller doing the common `ErrorView(message: 'Could not load X.\n$error')`
/// never has to remember to translate the raw exception itself - a
/// Firebase-style `[plugin/code]` tag anywhere in the text is rewritten
/// to plain language automatically.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              friendlyErrorText(message),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Retry',
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
