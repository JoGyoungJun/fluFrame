import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders an [AsyncValue] with sensible loading and error defaults.
///
/// Keeps `switch`ing over [AsyncValue] out of every screen; pass [onRetry]
/// to show a retry button and [messageOf] to customize the error message.
///
/// Once a value has been loaded it stays on screen: a refresh in flight
/// and a refresh that failed both keep rendering [data]. The spinner and
/// the error view are for the states where there is nothing to show yet.
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
    // AsyncValue carries "loading" and "failed" as flags over the state it
    // already holds, not as separate cases: after `ref.invalidate` the
    // value is the previous AsyncError with `isLoading` set, and a failed
    // refresh is an AsyncError that still carries the last data. Matching
    // on the sealed type alone therefore rendered a Retry tap as no
    // visible change at all — so users tapped it again, firing duplicate
    // requests — and replaced the list behind a failed pull-to-refresh
    // with a full-screen error.
    if (value.hasValue) {
      // Data the user is already reading outlives a refresh, successful or
      // not. A screen that must announce a failed refresh can `ref.listen`
      // its provider and show a snack bar.
      return data(value.requireValue);
    }
    if (value.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = value.error;
    return _ErrorView(
      message: error != null ? messageOf?.call(error) : null,
      onRetry: onRetry,
    );
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
