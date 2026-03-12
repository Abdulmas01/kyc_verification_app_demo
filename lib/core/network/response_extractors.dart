List<dynamic> extractList(dynamic data) {
  if (data is List) {
    return data;
  }
  if (data is Map && data["results"] is List) {
    return data["results"] as List;
  }
  return const [];
}
