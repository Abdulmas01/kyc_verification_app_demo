class QueryParams {
  final Map<String, dynamic> filters;
  final String? searchTerm;
  final String? sortBy;
  final String? sortOrder; // 'asc' or 'desc'
  final Map<String, dynamic> customParams;

  const QueryParams({
    this.filters = const {},
    this.searchTerm,
    this.sortBy,
    this.sortOrder,
    this.customParams = const {},
  });

  QueryParams copyWith({
    Map<String, dynamic>? filters,
    String? searchTerm,
    String? sortBy,
    String? sortOrder,
    Map<String, dynamic>? customParams,
  }) {
    return QueryParams(
      filters: filters ?? Map<String, dynamic>.from(this.filters),
      searchTerm: searchTerm ?? this.searchTerm,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      customParams:
          customParams ?? Map<String, dynamic>.from(this.customParams),
    );
  }

  /// Clear search term but keep other params
  QueryParams clearSearch() {
    return copyWith(searchTerm: '');
  }

  /// Clear all filters but keep other params
  QueryParams clearFilters() {
    return copyWith(filters: {});
  }

  /// Reset all query params
  QueryParams reset() {
    return const QueryParams();
  }

  /// Convert to URL query string
  Map<String, String> toQueryString() {
    final params = <String, String>{};

    // Add search term
    if (searchTerm != null && searchTerm!.isNotEmpty) {
      params['search'] = searchTerm!;
    }

    // Add sorting
    if (sortBy != null) {
      params['sort'] = sortBy!;
      if (sortOrder != null) {
        params['order'] = sortOrder!;
      }
    }

    // Add filters
    filters.forEach((key, value) {
      if (value != null) {
        params[key] = value.toString();
      }
    });

    // Add custom params
    customParams.forEach((key, value) {
      if (value != null) {
        params[key] = value.toString();
      }
    });

    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryParams &&
          runtimeType == other.runtimeType &&
          _mapEquals(filters, other.filters) &&
          searchTerm == other.searchTerm &&
          sortBy == other.sortBy &&
          sortOrder == other.sortOrder &&
          _mapEquals(customParams, other.customParams);

  @override
  int get hashCode =>
      filters.hashCode ^
      searchTerm.hashCode ^
      sortBy.hashCode ^
      sortOrder.hashCode ^
      customParams.hashCode;

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
