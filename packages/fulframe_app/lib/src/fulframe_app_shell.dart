import 'package:flutter/widgets.dart';

class FulFrameAppShell extends StatelessWidget {
  const FulFrameAppShell({
    required this.child,
    super.key,
    this.onError,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (details) {
      onError?.call(
        details.exception,
        details.stack ?? StackTrace.empty,
      );
      return const Center(child: Text('Something went wrong.'));
    };

    return child;
  }
}
