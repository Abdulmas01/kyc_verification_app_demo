import 'package:kyc_verification_app_demo/core/pagination/models/query_params.dart';

sealed class PaginatedRequest {
  final QueryParams queryParams;

  const PaginatedRequest({this.queryParams = const QueryParams()});

  PaginatedRequest copyWithQueryParams(QueryParams newParams);
  PaginatedRequest reset();
}

// Limit-offset request
final class LimitOffsetPaginatedRequest extends PaginatedRequest {
  final bool isFirstFetch;
  final int limit;
  final int offset;
  final int currentPage;

  const LimitOffsetPaginatedRequest({
    required this.isFirstFetch,
    required this.limit,
    required this.offset,
    required this.currentPage,
    super.queryParams,
  });

  LimitOffsetPaginatedRequest copyWith({
    bool? isFirstFetch,
    int? limit,
    int? offset,
    int? currentPage,
    QueryParams? queryParams,
  }) {
    return LimitOffsetPaginatedRequest(
      isFirstFetch: isFirstFetch ?? this.isFirstFetch,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      currentPage: currentPage ?? this.currentPage,
      queryParams: queryParams ?? this.queryParams,
    );
  }

  @override
  LimitOffsetPaginatedRequest copyWithQueryParams(QueryParams newParams) {
    return copyWith(queryParams: newParams);
  }

  LimitOffsetPaginatedRequest nextPage() {
    return copyWith(
      offset: offset + limit,
      currentPage: currentPage + 1,
    );
  }

  @override
  LimitOffsetPaginatedRequest reset() {
    return copyWith(offset: 0, currentPage: 0);
  }
}

// Page-based request (1-based)
final class PagePaginatedRequest extends PaginatedRequest {
  final int page;
  final int limit;

  const PagePaginatedRequest({
    required this.page,
    required this.limit,
    super.queryParams,
  });

  PagePaginatedRequest copyWith({
    int? page,
    int? limit,
    QueryParams? queryParams,
  }) {
    return PagePaginatedRequest(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      queryParams: queryParams ?? this.queryParams,
    );
  }

  @override
  PagePaginatedRequest copyWithQueryParams(QueryParams newParams) {
    return copyWith(queryParams: newParams);
  }

  PagePaginatedRequest nextPage() {
    return copyWith(page: page + 1);
  }

  @override
  PagePaginatedRequest reset() {
    return copyWith(page: 1);
  }
}

// Cursor-based request
final class CursorPaginatedRequest extends PaginatedRequest {
  final String? cursor;
  final int limit;

  const CursorPaginatedRequest({
    this.cursor,
    required this.limit,
    super.queryParams,
  });

  CursorPaginatedRequest copyWith({
    Object? cursor = _paginationUnset,
    int? limit,
    QueryParams? queryParams,
  }) {
    return CursorPaginatedRequest(
      cursor: cursor == _paginationUnset ? this.cursor : cursor as String?,
      limit: limit ?? this.limit,
      queryParams: queryParams ?? this.queryParams,
    );
  }

  @override
  CursorPaginatedRequest copyWithQueryParams(QueryParams newParams) {
    return copyWith(queryParams: newParams);
  }

  CursorPaginatedRequest nextPage(String newCursor) {
    return copyWith(cursor: newCursor);
  }

  @override
  CursorPaginatedRequest reset() {
    return CursorPaginatedRequest(
      cursor: null,
      limit: limit,
      queryParams: queryParams,
    );
  }
}

// Firebase request
final class FirebasePaginatedRequest extends PaginatedRequest {
  final dynamic lastDocument; // Firestore DocumentSnapshot
  final int limit;

  const FirebasePaginatedRequest({
    this.lastDocument,
    required this.limit,
    super.queryParams,
  });

  FirebasePaginatedRequest copyWith({
    Object? lastDocument = _paginationUnset,
    int? limit,
    QueryParams? queryParams,
  }) {
    return FirebasePaginatedRequest(
      lastDocument:
          lastDocument == _paginationUnset ? this.lastDocument : lastDocument,
      limit: limit ?? this.limit,
      queryParams: queryParams ?? this.queryParams,
    );
  }

  @override
  FirebasePaginatedRequest copyWithQueryParams(QueryParams newParams) {
    return copyWith(queryParams: newParams);
  }

  FirebasePaginatedRequest nextPage(dynamic newLastDocument) {
    return copyWith(lastDocument: newLastDocument);
  }

  @override
  FirebasePaginatedRequest reset() {
    return FirebasePaginatedRequest(
      lastDocument: null,
      limit: limit,
      queryParams: queryParams,
    );
  }
}

const Object _paginationUnset = Object();
