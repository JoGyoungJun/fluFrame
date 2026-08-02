import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders an [AsyncValue] with sensible loading and error defaults.
///
/// Keeps `switch`ing over [AsyncValue] out of every screen; pass [onRetry]
/// to show a retry button and [messageOf] to customize the error message.
class AsyncValueWidget<T> extends StatelessWidget {
  /// Creates an [AsyncValueWidget] rendering [value] through [data].
  const AsyncValueWidget({
    required this.value,
    required this.data,
    this.onRetry,
    this.messageOf,
    super.key,
  });

  /// The asynchronous value to render.
  final AsyncValue<T> value;

  /// Builds the widget for the data state.
  final Widget Function(T data) data;

  /// Invoked by the retry button in the error state; hidden when `null`.
  final VoidCallback? onRetry;

  /// Builds the message shown in the error state; falls back to the
  /// localized generic error message when `null`.
  final String Function(Object error)? messageOf;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(value: final content) => data(content),
      AsyncError(:final error) => _ErrorView(
        message: messageOf?.call(error),
        onRetry: onRetry,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message ?? l10n.genericErrorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
