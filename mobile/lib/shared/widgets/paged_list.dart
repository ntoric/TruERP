import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/paged.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'common.dart';

typedef PageFetcher<T> = Future<Paged<T>> Function(int page);

/// Infinite-scrolling list with pull-to-refresh, skeleton, empty and error
/// states. Change [resetKey] (e.g. search text + filters) to reload from page 1.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.resetKey,
    this.header,
    this.padding = const EdgeInsets.only(bottom: 96),
    this.separated = true,
  });

  final PageFetcher<T> fetch;
  final Widget Function(BuildContext, T item, int index) itemBuilder;
  final Widget empty;
  final Object? resetKey;

  /// Scrolls with the list (summary strip, filter chips…).
  final Widget? header;
  final EdgeInsets padding;
  final bool separated;

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  final _items = <T>[];
  final _scroll = ScrollController();
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNext();
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) _loadNext();
  }

  /// Reloads from the first page. Safe to call from parents via a GlobalKey.
  Future<void> refresh() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page;
        // Guard against servers that ignore paging and return everything.
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstLoad = _items.isEmpty && (_loading || (_error == null && _hasMore));
    Widget body;
    if (firstLoad) {
      body = const SliverFillRemaining(hasScrollBody: false, child: SkeletonList());
    } else if (_items.isEmpty && _error != null) {
      body = SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: refresh));
    } else if (_items.isEmpty) {
      body = SliverFillRemaining(hasScrollBody: false, child: widget.empty);
    } else {
      final count = _items.length + 1;
      body = SliverPadding(
        padding: widget.padding,
        sliver: SliverList.separated(
          itemCount: count,
          separatorBuilder: (_, i) => widget.separated && i < _items.length - 1
              ? const Divider(indent: 72, height: 1)
              : const SizedBox.shrink(),
          itemBuilder: (ctx, i) {
            if (i < _items.length) return widget.itemBuilder(ctx, _items[i], i);
            return _footer(ctx);
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          body,
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            Text(errorMessage(_error!), style: context.text.bodySmall, textAlign: TextAlign.center),
            TextButton(onPressed: _loadNext, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!_hasMore && _items.length > 8) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Center(child: Text('${_items.length} records', style: context.text.labelSmall)),
      );
    }
    return const SizedBox(height: Spacing.sm);
  }
}

/// Search box that reports changes after the user pauses typing.
class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Search', this.autofocus = false});
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => widget.onChanged(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _ctrl.clear();
                  _changed('');
                },
              ),
      ),
    );
  }
}
