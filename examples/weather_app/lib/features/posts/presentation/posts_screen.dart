import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_app/core/widgets/async_value_widget.dart';
import 'package:weather_app/core/widgets/content_width.dart';
import 'package:weather_app/features/posts/presentation/posts_controller.dart';
import 'package:weather_app/features/posts/presentation/posts_state.dart';
import 'package:weather_app/l10n/gen/app_localizations.dart';

/// How close to the bottom the user must scroll before the next page is
/// requested — roughly one screenful, so the list is already growing by
/// the time they get there.
const double _loadMoreThreshold = 400;

/// Lists posts from the sample API with infinite scroll, pull-to-refresh
/// and error retry.
class PostsScreen extends ConsumerStatefulWidget {
  /// Creates the posts screen.
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }
    // Fires on every frame while the user rests near the bottom. That is
    // fine: PostsController.loadMore drops the call when a page is already
    // in flight or there is nothing left, which is exactly why the guard
    // lives there and not here.
    unawaited(ref.read(postsControllerProvider.notifier).loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final posts = ref.watch(postsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.postsTitle)),
      body: AsyncValueWidget<PostsState>(
        value: posts,
        onRetry: () => ref.invalidate(postsControllerProvider),
        messageOf: (error) => l10n.postsErrorMessage,
        data: (state) {
          final footer = _footer(context, l10n, state);
          return RefreshIndicator(
            onRefresh: ref.read(postsControllerProvider.notifier).refresh,
            child: ListView.separated(
              controller: _scrollController,
              // Padding, not a ContentWidth wrapper: the scrollable stays
              // full-bleed so the mouse wheel and pull-to-refresh keep
              // working over the whole window, and only the rows move.
              padding: EdgeInsets.symmetric(
                horizontal: ContentWidth.insetFor(
                  MediaQuery.sizeOf(context).width,
                ),
              ),
              itemCount: state.posts.length + (footer == null ? 0 : 1),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.posts.length) return footer;
                final post = state.posts[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${post.id}')),
                  title: Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    post.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.go('/home/posts/${post.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// The item below the last post, or `null` when there is nothing to say.
  ///
  /// A failed next page never takes over the screen — the posts already
  /// loaded stay exactly where they are and the retry sits underneath
  /// them.
  Widget? _footer(
    BuildContext context,
    AppLocalizations l10n,
    PostsState state,
  ) {
    if (state.isLoadingMore) {
      return _FooterMessage(
        leading: const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        message: l10n.postsLoadingMore,
      );
    }
    if (state.loadMoreError != null) {
      return _FooterMessage(
        message: l10n.postsLoadMoreError,
        action: TextButton(
          onPressed: ref.read(postsControllerProvider.notifier).loadMore,
          child: Text(l10n.retry),
        ),
      );
    }
    if (!state.hasMore) {
      return _FooterMessage(message: l10n.postsEndOfList, muted: true);
    }
    return null;
  }
}

class _FooterMessage extends StatelessWidget {
  const _FooterMessage({
    required this.message,
    this.leading,
    this.action,
    this.muted = false,
  });

  final String message;
  final Widget? leading;
  final Widget? action;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}
