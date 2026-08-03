import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/widgets/async_value_widget.dart';
import 'package:todo_app/features/posts/domain/post.dart';
import 'package:todo_app/features/posts/presentation/posts_controller.dart';
import 'package:todo_app/l10n/gen/app_localizations.dart';

/// Lists posts from the sample API with pull-to-refresh and error retry.
class PostsScreen extends ConsumerWidget {
  /// Creates the posts screen.
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final posts = ref.watch(postsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.postsTitle)),
      body: AsyncValueWidget<List<Post>>(
        value: posts,
        onRetry: () => ref.invalidate(postsControllerProvider),
        messageOf: (error) => l10n.postsErrorMessage,
        data: (posts) => RefreshIndicator(
          onRefresh: ref.read(postsControllerProvider.notifier).refresh,
          child: ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final post = posts[index];
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
        ),
      ),
    );
  }
}
