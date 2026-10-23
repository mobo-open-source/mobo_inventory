import 'package:flutter/material.dart';

/// True when the screen is too short to keep a list screen's header (search
/// bar, filter chips, group summary) pinned above its list — in practice a
/// phone in landscape. Tablets in landscape stay above the threshold.
bool isCompactHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 500;

/// Lays out a list screen's [header] above its [body].
///
/// On a normal-height screen the header stays pinned above the list. On a
/// short one (see [isCompactHeight]) the header scrolls away with the list,
/// so the list gets the whole height instead of the sliver left between the
/// app bar, the header and the bottom bar.
///
/// For the header to scroll with the list, the vertical scrollable inside
/// [body] must not be given its own `controller` — it has to pick up the
/// [PrimaryScrollController] that [NestedScrollView] provides. On a
/// normal-height screen the body is cut off from any ancestor
/// [PrimaryScrollController], so that same scrollable falls back to a private
/// controller, exactly as if it had been given its own.
///
/// Anything that should sit at the top of the list on a short screen (e.g. a
/// "N groups · Expand All" row) belongs in [body] as the scrollable's first
/// item rather than in [header], so it scrolls too.
class CollapsibleHeaderLayout extends StatefulWidget {
  const CollapsibleHeaderLayout({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  @override
  State<CollapsibleHeaderLayout> createState() =>
      _CollapsibleHeaderLayoutState();
}

class _CollapsibleHeaderLayoutState extends State<CollapsibleHeaderLayout> {
  // Rotating swaps the Column for a NestedScrollView. The key moves the
  // header's elements across instead of rebuilding them, so a focused search
  // field keeps its focus (and the keyboard stays up). The body is not keyed:
  // its scroll position can't move between a plain controller and
  // NestedScrollView's, so it is rebuilt and starts at the top.
  final GlobalKey _headerKey = GlobalKey(debugLabel: 'CollapsibleHeader');

  @override
  Widget build(BuildContext context) {
    final header = KeyedSubtree(key: _headerKey, child: widget.header);

    if (!isCompactHeight(context)) {
      return Column(
        children: [
          header,
          Expanded(child: PrimaryScrollController.none(child: widget.body)),
        ],
      );
    }

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
      body: widget.body,
    );
  }
}
