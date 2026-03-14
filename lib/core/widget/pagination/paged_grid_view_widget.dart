import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/pagination/models/pagination_response.dart';
import 'package:kyc_verification_app_demo/core/theme/app_loader.dart';
import 'package:kyc_verification_app_demo/core/widget/full_page_error_widget.dart';

class PagedGridViewWidget<T> extends ConsumerStatefulWidget {
  const PagedGridViewWidget({
    super.key,
    this.scrollController,
    required this.asyncState,
    required this.paginationResponse,
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

    final shouldLoadMore = position.pixels >= threshold &&
        !_isLoadingMore &&
        hasMore &&
        !_hasError;

    if (shouldLoadMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      widget.onLoadMore();
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  bool get _isLoading => widget.asyncState is AsyncLoading;
  bool get _hasError => widget.asyncState is AsyncError;

  @override
  Widget build(BuildContext context) {
    final data = widget.paginationResponse?.data ?? [];
    final hasMore = widget.paginationResponse?.hasMoreData ?? false;

    if (_isLoading && data.isEmpty) {
      return widget.loader ?? const Center(child: AppLoader());
    }

    if (_hasError && data.isEmpty) {
      return FullPageErrorWidget(
        error: widget.asyncState.error,
        onRetry: widget.onRetry,
      );
    }

    if (data.isEmpty) {
      return widget.emptyWidget ??
          Center(
            child: Text(
              'No items found',
              style: context.textTheme.headlineMedium,
            ),
          );
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
                child: Text(
                  'No more data',
                  style: TextStyle(color: Colors.grey),
                ),
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
