import 'package:flutter/material.dart';
import 'package:weather_app/l10n/gen/app_localizations.dart';

/// Shown when a deep link contains an unparseable post id
/// (e.g. `/home/posts/abc`).
class PostNotFoundScreen extends StatelessWidget {
  /// Creates the not-found screen.
  const PostNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.postsTitle)),
      body: Center(child: Text(l10n.postNotFound)),
    );
  }
}
