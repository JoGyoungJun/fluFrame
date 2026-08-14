# 005 — Wide-viewport content width

> Historical record: written against fluframe 1.4.1; current behaviour is defined by the code and CHANGELOG.

Status: APPROVED

Every layout number in this spec was measured on Flutter 3.44.1 with a
widget test, not reasoned about. The first draft was reasoned about, and
an adversarial review found four separate places where the layout does
not do what it looks like it does — recorded under "What the first draft
got wrong" so the same mistakes are not re-derived later.

## Problem

Opened at desktop width, a generated app stretches body content edge to
edge. This became the first impression the project makes when the live
demo shipped: a visitor arrives in a desktop browser and sees a
phone app that was stretched, not one that handles the size.

Measured against `template/lib` at 1.4.1, only three screens are actually
unconstrained, and one of the issue's own complaints is about the
opposite:

| Screen | Body | At a wide window |
|---|---|---|
| `posts_screen` | `ListView.separated` of `ListTile` | title alone on the left, the rest of the row blank |
| `settings_screen` | `ListView(padding: 24)` | headers and controls stretched |
| `post_detail_screen` | `SingleChildScrollView(padding: 24) > Column(start)` | body text runs the full measure |
| `home_screen` | `Center > SingleChildScrollView(24) > ConstrainedBox(480)` | **already capped** — the issue's "small column floating in a very wide empty field" *is* this 480 |
| `login_screen` | same shape, 400 | already capped (a form) |
| `profile_screen` | `Center > Column(min)` | naturally narrow |
| `post_not_found_screen` | `Center > Text` | naturally narrow |

So this is not "add a constraint everywhere". It is: cap the three that
run wild, and give the cap one name so future screens inherit it.

## Goals

- Body content stops growing without bound on web, desktop and tablet.
- One documented place defines the content cap, and a feature added later
  inherits it without anyone remembering to.
- Nothing changes below the cap — identical layout at phone width, down
  to widget offsets.
- On desktop, the whole window keeps scrolling. Capping must not create
  dead gutters.

## Non-goals

- `NavigationRail` at wide widths. Out of scope per the issue; the bottom
  bar stays a bottom bar.
- Reflowing layouts: two-pane list/detail, grids, adaptive columns.
- **Touching `home_screen` or `login_screen` at all.** They are already
  capped and correct. See "What the first draft got wrong" #1 for why
  refactoring them through the new widget silently narrows them.

## Design

### Open question 1 — per-screen, not app-level

The issue offers "one app-level constraint in the shell route's builder"
versus "per-screen". **App-level is not available**, for two structural
reasons rather than a preference:

1. `AppNavigationShell` (`app_router.dart:156-197`) is a `Scaffold` whose
   `body:` is the `navigationShell`, and every screen owns its own
   `Scaffold` + `AppBar`. Constraining at `body: navigationShell` narrows
   the nested `AppBar` too, so the app bar would float in the same empty
   field the content just left. Material caps content and keeps app bars
   and navigation full-bleed.
2. The shell wraps only the three tab branches. `/login` and the
   `errorBuilder` screen are outside it, so a shell constraint would not
   be app-level anyway.

The real argument for app-level — "a new feature could forget it" — is
answered at the generator instead (see below), which also covers screens
that are not tab branches.

### Open question 2 — 840

`ContentWidth.maxContentWidth = 840`.

Material 3 window size classes: compact `< 600`, medium `600-839`,
expanded `840-1199`, large `1200-1599`, extra-large `1600+`. 840 is
exactly the expanded floor, so the rule reads *"content never grows past
the width at which Material calls the window expanded"* — a breakpoint,
not a taste call, which is what the issue asked for.

It also makes goal 3 free: below 840 the cap is arithmetically inert.

### Open question 3 — NavigationRail

Stays out of scope; the issue already answered this in its own Out of
scope section. No decision needed here.

### API surface — one widget, two ways in

New: `template/lib/core/widgets/content_width.dart`

```dart
/// Caps and centres body content so it does not run edge to edge when the
/// window is wide.
///
/// Wrap a `Scaffold`'s `body`, never the `Scaffold` itself: app bars and
/// navigation stay full-bleed, only the measure is capped.
///
/// For a **scrollable** body use [insetFor] as horizontal padding
/// instead of wrapping it — see the note there.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    required this.child,
    this.maxWidth = maxContentWidth,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// Material 3 calls a window "expanded" from 840dp. Capping there means
  /// content never grows past the width at which the layout is considered
  /// wide — and below it the cap does nothing, so phones are unaffected.
  static const double maxContentWidth = 840;

  /// Horizontal inset that centres [maxWidth] of content inside [width].
  ///
  /// Pass this to a scrollable's `padding` rather than wrapping the
  /// scrollable. A wrapped `ListView` only receives pointer events inside
  /// its own box, so on a 1400px window the outer 280px on each side stop
  /// responding to the mouse wheel and to pull-to-refresh. Padding keeps
  /// the scrollable full-bleed and moves only its items.
  static double insetFor(double width, [double maxWidth = maxContentWidth]) =>
      math.max(0, (width - maxWidth) / 2);

  final double maxWidth;

  /// Where the capped child sits. `topCenter` reproduces what
  /// `Scaffold.body` does today; `Center` would also re-centre vertically.
  final AlignmentGeometry alignment;

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        // Scaffold.body hands its child a TIGHT width and a loose height.
        // Align loosens both, so without this a shrink-wrapping child
        // (SingleChildScrollView > Column) collapses to its intrinsic
        // width and `crossAxisAlignment: start` stops meaning anything.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
}
```

**Measured** (Flutter 3.44.1, `devicePixelRatio: 1`), wrapping a
detail-shaped body — `SingleChildScrollView(padding: 24) > Column(start)`:

| Window | Title rect before | after |
|---|---|---|
| 390x900 | `left 24, top 80` | `left 24, top 80` — identical |
| 1400x900 | `left 24, top 80` | `left 304, top 80` — 280 inset + the 24 padding, top anchor unchanged |

**Measured** for a list at 1400x900:

| Approach | `Scrollable` rect | Row rect |
|---|---|---|
| wrapped in `ContentWidth` | `280 .. 1120` — gutters dead | `280 .. 1120` |
| `padding: insetFor(width)` | `0 .. 1400` — full-bleed | `280 .. 1120`, width 840 |

### Call sites

| File | Change |
|---|---|
| `features/posts/presentation/posts_screen.dart` | `ListView.separated(padding: EdgeInsets.symmetric(horizontal: ContentWidth.insetFor(MediaQuery.sizeOf(context).width)), …)` — scrollable stays full-bleed |
| `features/settings/presentation/settings_screen.dart` | existing `padding: EdgeInsets.all(24)` becomes `const EdgeInsets.all(24) + EdgeInsets.symmetric(horizontal: ContentWidth.insetFor(…))` |
| `features/posts/presentation/post_detail_screen.dart` | `body: ContentWidth(child: AsyncValueWidget(…))` — not a scrollable at the body level, so the wrapper is right |
| `home_screen`, `login_screen`, `profile_screen`, `post_not_found_screen` | **unchanged** |

### Generator

`packages/fluframe/lib/src/feature_scaffold.dart`'s `_screenSource` emits
a bare `Scaffold(body: AsyncValueWidget(…))`. It gains the `ContentWidth`
wrapper **conditionally**: `add feature` runs inside apps generated by
older fluframe versions, which have no `lib/core/widgets/content_width.dart`,
and emitting the import unconditionally would leave those apps not
compiling. The scaffold checks for that file in the target project and
falls back to the current output when it is absent.

### Data

None. No storage, no models, no providers.

## l10n keys

None. This changes layout only; `ContentWidth` renders no text.

## Test plan

| Test | Where | Asserts |
|---|---|---|
| caps a wide child | `template/test/core/content_width_test.dart` (new) | at 1400x900 the child renders 840 wide |
| inert below the cap | same | at 390x844 the child renders 390, and a detail-shaped child keeps `topLeft == (24, 80)` — offset, not just width |
| top-anchored, left-aligned | same | a short shrink-wrapping child stays at the left edge of the cap instead of collapsing to its intrinsic width |
| `insetFor` arithmetic | same | `insetFor(1400) == 280`, `insetFor(390) == 0`, `insetFor(840) == 0` |
| posts list capped, scrollable full-bleed | `template/test/features/posts/posts_screen_test.dart` | at 1400x900 the `ListTile` spans 280..1120 **and** the `Scrollable` spans 0..1400 |
| settings capped the same way | `template/test/features/settings/settings_screen_test.dart` | as above |
| detail capped | `template/test/features/posts/post_detail_screen_test.dart` | at 1400x900 the `SingleChildScrollView` renders 840 wide (**not** the inner column — it is inside 24pt padding, so its ceiling is 792) |
| phone width untouched | existing `language labels stay on one line at phone width` | passes with its body unmodified; the new cases are added alongside it |
| scaffolded screen inherits the cap | `packages/fluframe/test/feature_scaffold_test.dart` | with `content_width.dart` present the generated screen contains `ContentWidth`; **without** it, the generated screen compiles and contains no import of it |

Surface size uses the pattern already in the repo:
`tester.view.devicePixelRatio = 1; tester.view.physicalSize = const
Size(1400, 900); addTearDown(tester.view.reset);`

## Acceptance criteria

- [ ] `ContentWidth` exists in `template/lib/core/widgets/`, and 840
      appears there and nowhere else in `template/lib`.
- [ ] At 1400x900: the `ListTile` in `posts_screen` and the rows in
      `settings_screen` span x 280..1120, and `post_detail_screen`'s
      `SingleChildScrollView` renders 840 wide.
- [ ] At 1400x900 the `Scrollable` in `posts_screen` still spans the full
      0..1400 — the mouse wheel works over the gutters.
- [ ] At 390x844 every touched screen is unchanged **by offset, not only
      by width**: `post_detail_screen`'s title keeps `topLeft == (24, 80)`
      for a long and for a short post.
- [ ] `settings_screen_test.dart`'s existing `language labels stay on one
      line at phone width` passes with its body unmodified.
- [ ] `home_screen` and `login_screen` are not modified by this change —
      `git diff` touches neither file.
- [ ] `fluframe add feature` emits `ContentWidth` when the target app has
      `lib/core/widgets/content_width.dart`, and emits the current output
      when it does not; both asserted by CLI unit tests.
- [ ] The cap is documented alongside `template/lib/core/widgets/`, in
      the doc that describes the template app layers.
- [ ] `examples/todo_app` and `examples/weather_app` carry the change in
      their **shared** screens via `check_example_drift.dart --fix`, and
      their example-only screens — `todos_screen.dart`,
      `weather_screen.dart` — are hand-edited to match. The drift checker
      walks the template tree, so it can neither report nor fix those two;
      a green drift run does **not** prove they were updated.
- [ ] `flutter analyze` 0 issues, `flutter test` green in the template and
      both examples, template coverage at or above the CI floor (78).

## Open questions

None. All three the issue raised are settled above.

## What the first draft got wrong

Kept because each was found by running the layout, not by reading it, and
the same mistakes are easy to re-derive.

1. **Refactoring `home_screen`/`login_screen` through the new widget
   narrows them by 48px.** Their `ConstrainedBox(480)` sits *inside*
   `SingleChildScrollView(padding: 24)`, so 480 is the content column and
   the block is 528. Moving the cap outside makes the padding come out of
   it: measured 480 → 432 and 400 → 352, every control included. Resolved
   by not touching those files.
2. **`Center` centres on both axes.** `post_detail_screen` has no `Center`
   today, so adding one moved its title from `(24, 80)` to `(24, 312)`,
   and for a post shorter than the measure the whole subtree shrink-wrapped
   and centred horizontally — `(123.8, 422)`, with
   `crossAxisAlignment: start` rendered meaningless. Resolved by
   `Align(topCenter)` + `SizedBox(width: double.infinity)`.
3. **The detail column can never be 840.** It is inside 24pt padding, so
   792 is its ceiling. The criterion now names the scroll view.
4. **Wrapping a scrollable kills the gutters.** A wrapped `ListView` only
   gets pointer events inside its box: on a 1400px window the outer 280px
   each side stopped scrolling. Resolved by padding the scrollable instead
   of wrapping it — which is also why `ContentWidth` ships `insetFor`.
5. **The generator would emit an import into apps that lack the file.**
   `add feature` runs in apps generated by older versions. Resolved by
   making the wrapper conditional on the file existing.
6. **`check_example_drift` cannot carry the example-only screens.** It
   walks the template tree, and `todos_screen.dart` / `weather_screen.dart`
   exist only in the examples. The criterion now says they are hand work.
