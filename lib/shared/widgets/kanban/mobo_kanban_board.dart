import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';

/// Odoo's grouped kanban view: one column per group, side by side and
/// scrolled horizontally — Draft | Waiting | Ready | Done when grouped by
/// Status.
///
/// [groups] maps each group's label to its record count from the server, in
/// the order to show them. A column's header shows that count (not just the
/// cards loaded so far), its cards scroll on their own, and it loads its
/// records ([onLoadGroup]) the first time it is built. While it shows fewer
/// cards than its count it offers "Load more" ([onLoadMore]), as Odoo's
/// columns do.
///
/// Pulling down at the top of any column calls [onRefresh].
class MoboKanbanBoard<T> extends StatelessWidget {
  const MoboKanbanBoard({
    super.key,
    required this.groups,
    required this.loadedGroups,
    required this.onLoadGroup,
    required this.itemBuilder,
    this.onLoadMore,
    this.onRefresh,
    this.bottomPadding = 16,
  });

  /// Group label → record count.
  final Map<String, int> groups;

  /// Group label → the records loaded for it; absent until loaded.
  final Map<String, List<T>> loadedGroups;

  final Future<void> Function(String groupKey) onLoadGroup;
  final Future<void> Function(String groupKey)? onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function()? onRefresh;

  /// Room under each column's last card (e.g. to clear a FAB).
  final double bottomPadding;

  /// §11 column width.
  static const double columnWidth = 304;

  @override
  Widget build(BuildContext context) {
    final keys = groups.keys.toList();
    final board = ListView.separated(
      key: const ValueKey('kanbanBoard'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final key = keys[index];
        return SizedBox(
          width: columnWidth,
          child: _KanbanColumn<T>(
            key: ValueKey('kanbanColumn_$key'),
            groupKey: key,
            count: groups[key] ?? 0,
            items: loadedGroups[key],
            onLoad: onLoadGroup,
            onLoadMore: onLoadMore,
            itemBuilder: itemBuilder,
            bottomPadding: bottomPadding,
          ),
        );
      },
    );

    if (onRefresh == null) return board;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: Theme.of(context).primaryColor,
      // The columns' own vertical lists; the board itself scrolls sideways.
      notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
      child: board,
    );
  }
}

class _KanbanColumn<T> extends StatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.groupKey,
    required this.count,
    required this.items,
    required this.onLoad,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.bottomPadding,
  });

  final String groupKey;
  final int count;
  final List<T>? items;
  final Future<void> Function(String groupKey) onLoad;
  final Future<void> Function(String groupKey)? onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double bottomPadding;

  @override
  State<_KanbanColumn<T>> createState() => _KanbanColumnState<T>();
}

class _KanbanColumnState<T> extends State<_KanbanColumn<T>> {
  bool _loading = false;
  bool _loadingMore = false;

  /// Set once this column has asked for its records, so a load that fails
  /// (and leaves them absent) isn't retried on every rebuild. Cleared when
  /// the records go away again, e.g. after the filters changed.
  bool _requested = false;

  /// A load finished without records arriving: the column offers Retry.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant _KanbanColumn<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != null) {
      _requested = false;
      _failed = false;
    } else if (oldWidget.items != null) {
      _requested = false;
      _failed = false;
      _ensureLoaded();
    }
  }

  void _ensureLoaded() {
    if (widget.items != null || _requested) return;
    _requested = true;
    // Loading notifies the provider, which can't happen during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await widget.onLoad(widget.groupKey);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = widget.items == null;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || widget.onLoadMore == null) return;
    setState(() => _loadingMore = true);
    try {
      await widget.onLoadMore!(widget.groupKey);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? Colors.grey[850]! : Colors.white;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  /// §11 header: the group's name and its record count in brackets, e.g.
  /// "Clothes (77)", in a black pill. A long name is ellipsized; the count
  /// never is.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.groupKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pillStyle,
                ),
              ),
              const SizedBox(width: 6),
              Text('(${widget.count})', style: _pillStyle),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _pillStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  Widget _buildBody(bool isDark) {
    final items = widget.items;
    final padding = EdgeInsets.fromLTRB(10, 0, 10, widget.bottomPadding);

    if (items == null) {
      if (!_failed) return _ColumnShimmer(padding: padding);
      return ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final hasMore = widget.onLoadMore != null && items.length < widget.count;
    return ListView.builder(
      // Each column scrolls on its own; it must not take over the screen's
      // primary scroll controller, which would tie all columns together.
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: items.isEmpty ? 1 : items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No records',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          );
        }
        if (index == items.length) return _buildLoadMore(items.length);
        return widget.itemBuilder(context, items[index]);
      },
    );
  }

  Widget _buildLoadMore(int shown) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: TextButton(
          onPressed: _loadingMore ? null : _loadMore,
          child: _loadingMore
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Load more (${widget.count - shown})'),
        ),
      ),
    );
  }
}

/// §15 card skeletons while a column loads its first records.
class _ColumnShimmer extends StatelessWidget {
  const _ColumnShimmer({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[200]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[50]!,
      child: ListView(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 88,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
        ],
      ),
    );
  }
}
