import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_app/features/home/presentation/counter_controller.dart';
import 'package:weather_app/l10n/gen/app_localizations.dart';

/// Landing screen: shows the boilerplate intro, a counter demo, and a link
/// to the posts sample.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = ref.watch(counterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTab)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeGreeting,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.homeDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.counterLabel(count),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: ref.read(counterProvider.notifier).increment,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.increment),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/home/posts'),
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.viewPosts),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
