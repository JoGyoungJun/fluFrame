import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/network/api_exception.dart';
import 'package:todo_app/core/widgets/async_value_widget.dart';
import 'package:todo_app/features/posts/domain/post.dart';
import 'package:todo_app/features/posts/presentation/posts_controller.dart';
import 'package:todo_app/l10n/gen/app_localizations.dart';

/// Shows a single post fetched by id.
class PostDetailScreen extends ConsumerWidget {
  /// Creates a detail screen for the post identified by [postId].
  const PostDetailScreen({required this.postId, super.key});

  /// Identifier of the post to display.
  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final post = ref.watch(postProvider(postId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.postDetailTitle(postId))),
      body: AsyncValueWidget<Post>(
        value: post,
        onRetry: () => ref.invalidate(postProvider(postId)),
        messageOf: (error) =>
            error is ServerException && error.statusCode == 404
            ? l10n.postNotFound
            : l10n.postsErrorMessage,
        data: (post) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
