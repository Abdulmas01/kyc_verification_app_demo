import 'package:kyc_verification_app_demo/core/pagination/models/paginated_request.dart';

class PaginationService {
  /// Move to the next request, applying the minus-page rule for LimitOffset
  PaginatedRequest nextRequest(
    PaginatedRequest request, {
    bool hasData = true,
    String? newCursor,
    dynamic newLastDocument,
  }) {
    if (request is LimitOffsetPaginatedRequest) {
      if (!hasData) {
        // Minus-page rule
        return request.copyWith(
          offset: (request.offset - request.limit).clamp(0, request.offset),
          currentPage: (request.currentPage - 1).clamp(0, request.currentPage),
        );
      }
      return request.nextPage();
    }

    if (request is PagePaginatedRequest) {
      if (!hasData) {
        return request.copyWith(
            page: (request.page - 1).clamp(1, request.page));
      }
      return request.nextPage();
    }

    if (request is CursorPaginatedRequest) {
      final cursor = newCursor ?? request.cursor ?? '';
      return request.nextPage(cursor);
    }

    if (request is FirebasePaginatedRequest) {
      if (newLastDocument != null) {
        return request.nextPage(newLastDocument);
      }
      return request;
    }

    return request;
  }

  /// Reset the pagination request
  PaginatedRequest resetRequest(PaginatedRequest request) {
    return request.reset();
  }

  /// Merge new items into the old list, avoiding duplicates
  List<T> mergeWithoutDuplicates<T>(
    List<T> existing,
    List<T> incoming,
    bool Function(T a, T b) isDuplicate,
  ) {
    final result = List<T>.from(existing);
    for (final item in incoming) {
      if (!result.any((e) => isDuplicate(e, item))) {
        result.add(item);
      }
    }
    return result;
  }

  /// Handle fetch error and rollback page if needed
  PaginatedRequest handleError(PaginatedRequest request) {
    if (request is LimitOffsetPaginatedRequest) {
      return request.copyWith(
        offset: (request.offset - request.limit).clamp(0, request.offset),
        currentPage: (request.currentPage - 1).clamp(0, request.currentPage),
      );
    }
    return request;
  }
}
