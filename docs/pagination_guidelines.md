# Pagination Guidelines

These rules apply to any pagination feature in this project. Keep pagination consistent, testable, and controller-friendly.

## Core Models
- Use `PaginationResponse<T>` and one of its concrete types: `LimitOffsetPaginationResponse`, `CursorPaginationResponse`, or `FirebasePaginationResponse`.
- Use `PaginatedRequest` and one of its concrete types: `LimitOffsetPaginatedRequest`, `CursorPaginatedRequest`, or `FirebasePaginatedRequest`.
- Always store paginated data in a response model, not raw lists in UI state.
- Prefer `PagePaginationResponse` + `PagePaginatedRequest` when the API is page-based (1-based).

## Controller Pattern
- Controllers own pagination state, not widgets.
- Use `AsyncValue` for loading and error states.
- Keep pagination request + response together in a single state object.
- Only the controller should advance pages or reset pagination.
- Every pagination controller must expose three methods:
  - `fetch()` (initial or current page)
  - `fetchMore()` (next page)
  - `resetAndFetch()` (reset pagination and reload)

## Service Helper
- Use `PaginationService` for page advancement and merging, not ad-hoc math.
- Use `nextRequest` to move the request forward after a successful fetch.
- Use `handleError` to roll back when needed.
- Use `mergeWithoutDuplicates` to avoid repeating items.

## Error Handling
- Store API error messages in `PaginationResponse.errorMessage` when available.
- Use `NetworkFailure` message and code to decide UI messaging.
- For status codes >= 500, show a server error state.

## Reset Behavior
- When starting a new query, reset both request and response.
- Use `.reset()` for requests and responses; do not build ad-hoc objects.
- Reset should clear cursors or last document references.
- Page-based reset must return to page 1 (not 0).

## Mapping
- Use `fromMap` on pagination responses when decoding API data.
- If the backend uses different list keys, pass `dataKey` to `fromMap`.
- Favor response parsing in repositories or data sources, not UI.

## Example Controller Pattern
```dart
class ListingState {
  const ListingState({
    required this.request,
    required this.response,
    required this.loadingState,
  });

  final LimitOffsetPaginatedRequest request;
  final LimitOffsetPaginationResponse<Item> response;
  final AsyncValue<void> loadingState;

  ListingState copyWith({
    LimitOffsetPaginatedRequest? request,
    LimitOffsetPaginationResponse<Item>? response,
    AsyncValue<void>? loadingState,
  }) {
    return ListingState(
      request: request ?? this.request,
      response: response ?? this.response,
      loadingState: loadingState ?? this.loadingState,
    );
  }
}

class ListingController extends AutoDisposeNotifier<ListingState> {
  late final PaginationService _paginationService;

  @override
  ListingState build() {
    _paginationService = PaginationService();
    return ListingState(
      request: const LimitOffsetPaginatedRequest(
        isFirstFetch: true,
        limit: 20,
        offset: 0,
        currentPage: 0,
      ),
      response: const LimitOffsetPaginationResponse(
        data: [],
        hasMoreData: true,
        limit: 20,
        offset: 0,
        currentPage: 0,
      ),
      loadingState: const AsyncValue.data(null),
    );
  }

  Future<void> fetch() async {
    if (state.loadingState.isLoading) return;
    state = state.copyWith(loadingState: const AsyncValue.loading());

    try {
      final response = await fetchFromApi(
        limit: state.request.limit,
        offset: state.request.offset,
      );

      state = state.copyWith(
        response: response,
        request: _paginationService.nextRequest(
          state.request,
          hasData: response.data.isNotEmpty,
        ) as LimitOffsetPaginatedRequest,
        loadingState: const AsyncValue.data(null),
      );
    } catch (e, st) {
      state = state.copyWith(loadingState: AsyncValue.error(e, st));
    }
  }
}
```

## Reusable Pagination Widgets

### Paginated Grid View (Sliver-based)
Use this pattern for grid pagination. It should not contain business logic.

```dart
class PagedGridViewWidget<T> extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final AsyncValue asyncState;
  final PaginationResponse<T>? paginationResponse;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Future<void> Function()? onRefresh;
  final Widget? loader;
  final Widget? emptyWidget;
  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisExtent;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double paginationThreshold;
  final EdgeInsets? padding;

  const PagedGridViewWidget({
    super.key,
    this.scrollController,
    required this.asyncState,
    required this.pagination,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    this.onRefresh,
    this.loader,
    this.emptyWidget,
    this.crossAxisCount = 2,
    this.childAspectRatio = 175 / 260,
    this.mainAxisExtent = 240,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 10,
    this.paginationThreshold = 0.8,
    this.padding,
  });

  @override
  ConsumerState<PagedGridViewWidget<T>> createState() =>
      _PagedGridViewWidgetState<T>();
}

class _PagedGridViewWidgetState<T>
    extends ConsumerState<PagedGridViewWidget<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PagedGridViewWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _scrollController.removeListener(_onScroll);
      if (widget.scrollController == null &&
          oldWidget.scrollController != null) {
        _scrollController.dispose();
        _scrollController = ScrollController();
      } else if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
      }
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final threshold = position.maxScrollExtent * widget.paginationThreshold;
    final hasMore = widget.paginationResponse?.hasMoreData ?? false;

    final shouldLoadMore =
        position.pixels >= threshold &&
        !_isLoadingMore &&
        hasMore &&
        !_hasError;

    if (shouldLoadMore) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      widget.onLoadMore();
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  bool get _isLoading => widget.asyncState is AsyncLoading;
  bool get _hasError => widget.asyncState is AsyncError;

  @override
  Widget build(BuildContext context) {
    final data = widget.paginationResponse?.data ?? [];
    final hasMore = widget.paginationResponse?.hasMoreData ?? false;

    if (_isLoading && data.isEmpty) {
      return widget.loader ?? const SizedBox.shrink();
    }

    if (_hasError && data.isEmpty) {
      return FullPageErrorWidget(error: widget.asyncState.error, onRetry: widget.onRetry);
    }

    if (data.isEmpty) {
      return widget.emptyWidget ??
          Center(child: Text('No items found', style: context.textTheme.headlineMedium));
    }

    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              childAspectRatio: widget.childAspectRatio,
              crossAxisSpacing: widget.crossAxisSpacing,
              mainAxisSpacing: widget.mainAxisSpacing,
              mainAxisExtent: widget.mainAxisExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => widget.itemBuilder(context, data[index]),
              childCount: data.length,
            ),
          ),
        ),
        if ((_isLoading || _isLoadingMore) && data.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (!_isLoading && !_isLoadingMore && !hasMore && data.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No more data', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ),
      ],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: scrollView);
    }

    return scrollView;
  }
}
```

### Paginated List View
Use this pattern for list pagination with optional separators.

```dart
class PaginatedListViewWidget<T> extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final AsyncValue asyncState;
  final PaginationResponse<T>? paginationResponse;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Future<void> Function()? onRefresh;
  final Widget? loader;
  final Widget? emptyWidget;
  final Widget Function(BuildContext, int index)? separatorBuilder;
  final double paginationThreshold;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;

  const PaginatedListViewWidget({
    super.key,
    this.scrollController,
    required this.asyncState,
    required this.pagination,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    this.onRefresh,
    this.loader,
    this.emptyWidget,
    this.separatorBuilder,
    this.paginationThreshold = 0.8,
    this.padding,
    this.physics,
  });

  @override
  ConsumerState<PaginatedListViewWidget<T>> createState() =>
      _PaginatedListViewWidgetState<T>();
}

class _PaginatedListViewWidgetState<T>
    extends ConsumerState<PaginatedListViewWidget<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PaginatedListViewWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _scrollController.removeListener(_onScroll);
      if (widget.scrollController == null &&
          oldWidget.scrollController != null) {
        _scrollController.dispose();
        _scrollController = ScrollController();
      } else if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
      }
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final threshold = position.maxScrollExtent * widget.paginationThreshold;
    final hasMore = widget.paginationResponse?.hasMoreData ?? false;

    final shouldLoadMore =
        position.pixels >= threshold &&
        !_isLoadingMore &&
        hasMore &&
        !_hasError;

    if (shouldLoadMore) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      widget.onLoadMore();
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  bool get _isLoading => widget.asyncState is AsyncLoading;
  bool get _hasError => widget.asyncState is AsyncError;

  @override
  Widget build(BuildContext context) {
    final data = widget.paginationResponse?.data ?? [];
    final hasMore = widget.paginationResponse?.hasMoreData ?? false;

    if (_isLoading && data.isEmpty) {
      return widget.loader ?? const SizedBox.shrink();
    }

    if (_hasError && data.isEmpty) {
      return FullPageErrorWidget(error: widget.asyncState.error, onRetry: widget.onRetry);
    }

    if (data.isEmpty) {
      return widget.emptyWidget ??
          Center(child: Text('No items found', style: context.textTheme.headlineMedium));
    }

    Widget listContent;

    if (widget.separatorBuilder != null) {
      listContent = ListView.separated(
        controller: _scrollController,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: data.length + 1,
        itemBuilder: (context, index) {
          if (index == data.length) {
            return _buildBottomWidget(hasMore, data.isNotEmpty);
          }
          return widget.itemBuilder(context, data[index], index);
        },
        separatorBuilder: (context, index) {
          if (index == data.length - 1) return const SizedBox.shrink();
          return widget.separatorBuilder!(context, index);
        },
      );
    } else {
      listContent = ListView.builder(
        controller: _scrollController,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: data.length + 1,
        itemBuilder: (context, index) {
          if (index == data.length) {
            return _buildBottomWidget(hasMore, data.isNotEmpty);
          }
          return widget.itemBuilder(context, data[index], index);
        },
      );
    }

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: listContent);
    }

    return listContent;
  }

  Widget _buildBottomWidget(bool hasMore, bool hasData) {
    if (!hasData) return const SizedBox.shrink();

    if ((_isLoading || _isLoadingMore) && hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_isLoading && !_isLoadingMore && !hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No more data', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
```

## Tests
- Add unit tests for `nextRequest`, `reset`, and `fromMap` behaviors.
- Add one widget test that drives the controller through a fetch and verifies UI updates.
- Do not rely on network calls in tests. Use fakes or provider overrides.
