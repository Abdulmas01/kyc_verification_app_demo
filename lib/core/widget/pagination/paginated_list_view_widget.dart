import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/pagination/models/pagination_response.dart';
import 'package:kyc_verification_app_demo/core/theme/app_loader.dart';
import 'package:kyc_verification_app_demo/core/widget/full_page_error_widget.dart';

class PaginatedListViewWidget<T> extends ConsumerStatefulWidget {
  const PaginatedListViewWidget({
    super.key,
    this.scrollController,
    required this.asyncState,
    required this.paginationResponse,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    this.header,
    this.onRefresh,
    this.loader,
    this.emptyWidget,
    this.separatorBuilder,
    this.paginationThreshold = 0.8,
    this.padding,
    this.physics,
  });

  final ScrollController? scrollController;
  final AsyncValue asyncState;
  final PaginationResponse<T>? paginationResponse;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Widget? header;
  final Future<void> Function()? onRefresh;
  final Widget? loader;
  final Widget? emptyWidget;
  final Widget Function(BuildContext, int index)? separatorBuilder;
  final double paginationThreshold;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;

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

    Widget listContent;
    final headerOffset = widget.header == null ? 0 : 1;

    if (widget.separatorBuilder != null) {
      listContent = ListView.separated(
        controller: _scrollController,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: data.length + 1 + headerOffset,
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) {
            return widget.header!;
          }
          final dataIndex = index - headerOffset;
          if (dataIndex == data.length) {
            return _buildBottomWidget(hasMore, data.isNotEmpty);
          }
          return widget.itemBuilder(context, data[dataIndex], dataIndex);
        },
        separatorBuilder: (context, index) {
          final dataIndex = index - headerOffset;
          if (dataIndex == data.length - 1) {
            return const SizedBox.shrink();
          }
          if (dataIndex < 0) {
            return widget.separatorBuilder!(context, 0);
          }
          return widget.separatorBuilder!(context, dataIndex);
        },
      );
    } else {
      listContent = ListView.builder(
        controller: _scrollController,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: data.length + 1 + headerOffset,
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) {
            return widget.header!;
          }
          final dataIndex = index - headerOffset;
          if (dataIndex == data.length) {
            return _buildBottomWidget(hasMore, data.isNotEmpty);
          }
          return widget.itemBuilder(context, data[dataIndex], dataIndex);
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
