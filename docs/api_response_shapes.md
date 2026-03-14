# API Response Shapes — Edge Cases and Client Handling

## Goal
We want predictable client parsing without refactoring every endpoint. This doc
summarizes the edge cases we hit, why they happen, and the agreed solution.

## The Two Response Shapes We See

### 1) Non‑paginated list
```json
[
  { "id": 1, "course_title": "Math", "level": "100 level" }
]
```

### 2) Paginated list (Django)
```json
{
  "count": 120,
  "next": "https://api/.../announcement?offset=10&limit=10",
  "previous": null,
  "results": [
    { "id": 1, "title": "Holiday" }
  ]
}
```

## Edge Cases We Hit
1. A list endpoint returns a **plain list** (works for list parsers, fails for
   pagination parsers).
2. A list endpoint returns a **map with results** (works for pagination
   parsers, fails for list parsers).
3. Paginated endpoints always return `count/next/previous/results` (Django),
   but `next` can be `null` on the last page, which does **not** mean it’s not
   paginated.

## Why We Don’t Normalize Everything in Dio
If we normalize all responses to a list, we **lose pagination metadata**:
`count`, `next`, `previous`. That breaks pagination UX.

## The Agreed Solution
### Rule of thumb
- **Paginated endpoints** → keep the full map and parse with
  `PaginationResponse.fromMap(...)`.
- **Non‑paginated endpoints** → return a `List<T>` and parse directly.

### Helper for non‑paginated endpoints
```dart
List<dynamic> extractList(dynamic data) {
  if (data is List) {
    return data;
  }
  if (data is Map && data["results"] is List) {
    return data["results"] as List;
  }
  return const [];
}
```

Use this **only** on non‑paginated endpoints (e.g., courses) so they stay
resilient if the backend accidentally returns `{ results: [...] }`.

## Examples

### Non‑paginated endpoint (Courses)
```dart
final response = await _client.get(Endpoints.coursesPath, ...);
final results = extractList(response.data);
return results.map((e) => Coursemodel.fromjson(e)).toList();
```

### Paginated endpoint (Announcements)
```dart
final response = await _client.get(Endpoints.announcementPath, ...);
return LimitOffsetPaginationResponse.fromMap(
  map: response.data,
  fromJson: (json) => AnnouncementModel.fromjson(json),
);
```

## Summary
- We avoid a global Dio normalizer to protect pagination metadata.
- We use a tiny list extractor only where pagination is not required.
- This keeps behavior consistent with Django pagination and avoids refactors.
