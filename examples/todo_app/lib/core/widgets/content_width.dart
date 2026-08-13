import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Caps and centres body content so it does not run edge to edge when the
/// window is wide (design spec 005).
///
/// Wrap a [Scaffold]'s `body`, never the [Scaffold] itself: app bars and
/// navigation stay full-bleed and only the measure is capped, which is
/// what Material asks for.
///
/// For a **scrollable** body do not wrap it — pass [insetFor] as its
/// horizontal padding instead. See that method for why.
class ContentWidth extends StatelessWidget {
  /// Caps [child] at [maxWidth] and places it at [alignment].
  const ContentWidth({
    required this.child,
    this.maxWidth = maxContentWidth,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// The widest body content is allowed to get.
  ///
  /// Material 3 calls a window "expanded" from 840dp, so capping here
  /// means content never grows past the width at which the layout is
  /// considered wide. Below it the cap is arithmetically inert, which is
  /// what keeps phone and tablet-portrait layout untouched.
  static const double maxContentWidth = 840;

  /// Horizontal inset that centres [maxWidth] of content inside [width].
  ///
  /// Pass this to a scrollable's `padding` rather than wrapping the
  /// scrollable in a [ContentWidth]. A wrapped `ListView` only receives
  /// pointer events inside its own box, so on a 1400px window the outer
  /// 280px on each side stop responding to the mouse wheel and to
  /// pull-to-refresh. Padding leaves the scrollable full-bleed and moves
  /// only its items.
  static double insetFor(double width, [double maxWidth = maxContentWidth]) =>
      math.max(0, (width - maxWidth) / 2);

  /// The cap applied to [child].
  final double maxWidth;

  /// Where the capped [child] sits in the space it was given.
  ///
  /// `topCenter` reproduces what `Scaffold.body` does today. [Center]
  /// would also re-centre vertically, which moves content that used to
  /// start at the top of the screen.
  final AlignmentGeometry alignment;

  /// The content being capped.
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      // Scaffold.body hands its child a TIGHT width and a loose height.
      // Align loosens both, so without this a shrink-wrapping child
      // (SingleChildScrollView > Column) collapses to its intrinsic width
      // and `crossAxisAlignment: start` stops meaning anything.
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
