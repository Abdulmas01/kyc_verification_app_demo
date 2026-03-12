// ignore_for_file: use_super_parameters

/// Base sealed class for all pagination responses
sealed class PaginationResponse<T> {
  final List<T> data;
  final bool hasMoreData;
  final String? errorMessage;

  const PaginationResponse({
    required this.data,
    required this.hasMoreData,
    this.errorMessage,
  });

  Map<String, dynamic> toMap();
}

const Object _paginationUnset = Object();

/// Cursor-based pagination
final class CursorPaginationResponse<T> extends PaginationResponse<T> {
  final String? cursor;
  final String? previousCursor;

  const CursorPaginationResponse({
    required List<T> data,
    required bool hasMoreData,
    super.errorMessage,
    this.cursor,
    this.previousCursor,
  }) : super(
          data: data,
          hasMoreData: hasMoreData,
        );

  CursorPaginationResponse<T> copyWith({
    List<T>? data,
    bool? hasMoreData,
    Object? errorMessage = _paginationUnset,
    Object? cursor = _paginationUnset,
    Object? previousCursor = _paginationUnset,
  }) {
    return CursorPaginationResponse<T>(
      data: data ?? this.data,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      errorMessage: errorMessage == _paginationUnset
          ? this.errorMessage
          : errorMessage as String?,
      cursor: cursor == _paginationUnset ? this.cursor : cursor as String?,
      previousCursor: previousCursor == _paginationUnset
          ? this.previousCursor
          : previousCursor as String?,
    );
  }

  CursorPaginationResponse<T> nextPage(String? newCursor) {
    return copyWith(
      previousCursor: cursor,
      cursor: newCursor,
    );
  }

  CursorPaginationResponse<T> reset() {
    return CursorPaginationResponse<T>(
      data: [],
      hasMoreData: true,
      errorMessage: null,
      cursor: null,
      previousCursor: null,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        "results": data,
        'hasMoreData': hasMoreData,
        'errorMessage': errorMessage,
        'cursor': cursor,
        'previousCursor': previousCursor,
      };

  factory CursorPaginationResponse.fromMap({
    required Map<String, dynamic> map,
    required T Function(Map<String, dynamic>) fromJson,
    String dataKey = "results",
  }) {
    final dataSource = map[dataKey];
    return CursorPaginationResponse<T>(
      data: dataSource is List
          ? dataSource
              .whereType<Map>()
              .map((e) => fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <T>[],
      hasMoreData: _boolValue(map, 'hasMoreData') ??
          _boolValue(map, 'hasNextPage') ??
          false,
      errorMessage: _stringValue(map, 'errorMessage'),
      cursor: _stringValue(map, 'cursor'),
      previousCursor: _stringValue(map, 'previousCursor'),
    );
  }
}

// Limit-offset pagination
final class LimitOffsetPaginationResponse<T> extends PaginationResponse<T> {
  final int limit;
  final int offset;
  final int currentPage;

  const LimitOffsetPaginationResponse({
    required List<T> data,
    required bool hasMoreData,
    super.errorMessage,
    required this.limit,
    required this.offset,
    required this.currentPage,
  }) : super(
          data: data,
          hasMoreData: hasMoreData,
        );

  LimitOffsetPaginationResponse<T> copyWith({
    List<T>? data,
    bool? hasMoreData,
    Object? errorMessage = _paginationUnset,
    int? limit,
    int? offset,
    int? currentPage,
  }) {
    return LimitOffsetPaginationResponse<T>(
      data: data ?? this.data,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      errorMessage: errorMessage == _paginationUnset
          ? this.errorMessage
          : errorMessage as String?,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  LimitOffsetPaginationResponse<T> nextPage() {
    return copyWith(
      offset: offset + limit,
      currentPage: currentPage + 1,
    );
  }

  LimitOffsetPaginationResponse<T> reset() {
    return copyWith(
      offset: 0,
      currentPage: 0,
      data: [],
      hasMoreData: true,
      errorMessage: null,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        "results": data,
        'hasMoreData': hasMoreData,
        'errorMessage': errorMessage,
        'limit': limit,
        'offset': offset,
        'currentPage': currentPage,
      };

  factory LimitOffsetPaginationResponse.fromMap({
    required Map<String, dynamic> map,
    required T Function(Map<String, dynamic>) fromJson,
    String dataKey = "results",
  }) {
    final dataSource = map[dataKey];
    return LimitOffsetPaginationResponse<T>(
      data: dataSource is List
          ? dataSource
              .whereType<Map>()
              .map((e) => fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <T>[],
      hasMoreData: _boolValue(map, 'hasMoreData') ??
          _boolValue(map, 'hasNextPage') ??
          false,
      errorMessage: _stringValue(map, 'errorMessage'),
      limit: _intValue(map, 'limit') ?? 0,
      offset: _intValue(map, 'offset') ?? 0,
      currentPage: _intValue(map, 'currentPage') ?? 0,
    );
  }
}

// Page-based pagination
final class PagePaginationResponse<T> extends PaginationResponse<T> {
  final int currentPage;
  final int? totalPages;
  final int? totalItems;

  const PagePaginationResponse({
    required List<T> data,
    required bool hasMoreData,
    super.errorMessage,
    required this.currentPage,
    this.totalPages,
    this.totalItems,
  }) : super(
          data: data,
          hasMoreData: hasMoreData,
        );

  PagePaginationResponse<T> copyWith({
    List<T>? data,
    bool? hasMoreData,
    Object? errorMessage = _paginationUnset,
    int? currentPage,
    int? totalPages,
    int? totalItems,
  }) {
    return PagePaginationResponse<T>(
      data: data ?? this.data,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      errorMessage: errorMessage == _paginationUnset
          ? this.errorMessage
          : errorMessage as String?,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
    );
  }

  PagePaginationResponse<T> nextPage() {
    return copyWith(currentPage: currentPage + 1);
  }

  PagePaginationResponse<T> reset() {
    return PagePaginationResponse<T>(
      data: [],
      hasMoreData: true,
      errorMessage: null,
      currentPage: 1,
      totalPages: null,
      totalItems: null,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        "results": data,
        'hasMoreData': hasMoreData,
        'errorMessage': errorMessage,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'totalItems': totalItems,
      };

  factory PagePaginationResponse.fromMap({
    required Map<String, dynamic> map,
    required T Function(Map<String, dynamic>) fromJson,
    String dataKey = "results",
  }) {
    final dataSource = map[dataKey];
    return PagePaginationResponse<T>(
      data: dataSource is List
          ? dataSource
              .whereType<Map>()
              .map((e) => fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <T>[],
      hasMoreData: _boolValue(map, 'hasMoreData') ??
          _boolValue(map, 'hasNextPage') ??
          false,
      errorMessage: _stringValue(map, 'errorMessage'),
      currentPage: _intValue(map, 'currentPage') ?? 1,
      totalPages: _intValue(map, 'totalPages'),
      totalItems: _intValue(map, 'totalItems'),
    );
  }
}

// Firebase pagination
final class FirebasePaginationResponse<T> extends PaginationResponse<T> {
  final dynamic lastDocument; // Typically a DocumentSnapshot in Firestore
  final int limit;

  const FirebasePaginationResponse({
    required List<T> data,
    required bool hasMoreData,
    super.errorMessage,
    this.lastDocument,
    required this.limit,
  }) : super(
          data: data,
          hasMoreData: hasMoreData,
        );

  FirebasePaginationResponse<T> copyWith({
    List<T>? data,
    bool? hasMoreData,
    Object? errorMessage = _paginationUnset,
    Object? lastDocument = _paginationUnset,
    int? limit,
  }) {
    return FirebasePaginationResponse<T>(
      data: data ?? this.data,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      errorMessage: errorMessage == _paginationUnset
          ? this.errorMessage
          : errorMessage as String?,
      lastDocument:
          lastDocument == _paginationUnset ? this.lastDocument : lastDocument,
      limit: limit ?? this.limit,
    );
  }

  FirebasePaginationResponse<T> nextPage(dynamic newLastDocument) {
    return copyWith(
      lastDocument: newLastDocument,
    );
  }

  FirebasePaginationResponse<T> reset() {
    return FirebasePaginationResponse<T>(
      data: [],
      hasMoreData: true,
      errorMessage: null,
      lastDocument: null,
      limit: limit,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        "results": data,
        'hasMoreData': hasMoreData,
        'errorMessage': errorMessage,
        'lastDocument': lastDocument
            ?.toString(), // Firestore snapshots can't be directly serialized
        'limit': limit,
      };

  factory FirebasePaginationResponse.fromMap({
    required Map<String, dynamic> map,
    required T Function(Map<String, dynamic>) fromJson,
    String dataKey = "results",
  }) {
    final dataSource = map[dataKey];
    return FirebasePaginationResponse<T>(
      data: dataSource is List
          ? dataSource
              .whereType<Map>()
              .map((e) => fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <T>[],
      hasMoreData: _boolValue(map, 'hasMoreData') ??
          _boolValue(map, 'hasNextPage') ??
          false,
      errorMessage: _stringValue(map, 'errorMessage'),
      lastDocument: map['lastDocument'],
      limit: _intValue(map, 'limit') ?? 0,
    );
  }
}

bool? _boolValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return null;
}

int? _intValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _stringValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}
