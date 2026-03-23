````md
# Riverpod Guidelines (Practical “Most Common Issues” Playbook)

These are **opinionated, practical guidelines** to avoid the most common Riverpod problems: rebuild bugs, stale data, memory leaks, awkward async handling, and “why is this fetching again?” issues.

This version uses **pure classes (no code generation, no decorators)**.

---

## 1) Prefer `Notifier` / `AutoDisposeNotifier`
Avoid:
- `StateNotifier` for new code
- `StateProvider` for business logic

Use:
- `Notifier`
- `AutoDisposeNotifier`

### Example
```dart
class Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final counterProvider =
    NotifierProvider<Counter, int>(Counter.new);
````

Usage:

```dart
final count = ref.watch(counterProvider);

ref.read(counterProvider.notifier).increment();
```

---

## 2) Use `AutoDisposeNotifier` for short-lived state

Use this for:

* Search pages
* Detail screens
* Temporary flows

### Example

```dart
class SearchQuery extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final searchQueryProvider =
    AutoDisposeNotifierProvider<SearchQuery, String>(
        SearchQuery.new);
```

This ensures memory is released when the screen is removed.

---

## 2.1) Pagination Controllers Contract

When you add pagination, the controller must expose:
- `fetch()` for the initial/current page
- `fetchMore()` for the next page
- `resetAndFetch()` to clear state and reload from page 1

Keep the pagination request + response together in the controller state.
Do not advance pages in the widget.

---
````md
## 2.2) Request Cancellation (Keep Dio Out of Repos)

If you need cancelable requests (e.g., polling or uploads), keep Dio-specific
types inside the data source. Pass a neutral cancel token through request
models instead.

Pattern:
- Create a `RequestCancelToken` wrapper (no Dio types exposed).
- Add `cancelToken` to request models.
- Data source maps `RequestCancelToken` to `CancelToken` internally.

This keeps repositories framework-agnostic and easy to mock.

Example:
```dart
final token = RequestCancelToken();

await repo.uploadVerification(
  UploadVerificationRequest(
    sessionToken: session.sessionToken,
    documentImage: documentImage,
    selfieImage: selfieImage,
    cancelToken: token,
  ),
);

// Later (e.g., on dispose)
token.cancel('User left screen');
```
````

---
````md
## 3) Retry Pattern (Using `Notifier` / `AutoDisposeNotifier` with `AsyncValue<User?>`)

Use this pattern when you want:
- a **retry button**
- **manual fetch on first frame** in a `StatefulWidget`
- to avoid `AsyncNotifier`, but still keep the state as `AsyncValue`

Key idea:
- The provider is a normal `Notifier`, but its `state` is `AsyncValue<User?>`.
- `build()` returns `AsyncData(null)` so the UI can decide when to load.

---

### Provider (pure class, no decorators)

```dart
class UserController extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() {
    // Initial state: "no data yet" (not loading)
    return const AsyncData(null);
  }

  Future<void> load() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final user = await fetchUser();
      return user; // User
    });
  }

  Future<void> retry() async => load();

  void clear() {
    state = const AsyncData(null);
  }
}

final userProvider =
    NotifierProvider<UserController, AsyncValue<User?>>(UserController.new);
````

---

### Usage in a `StatefulWidget` (fetch on load + retry)

```dart
class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // fetch on first frame
      ref.read(userProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
      data: (user) {
        // user can be null initially
        if (user == null) {
          return Center(
            child: ElevatedButton(
              onPressed: () => ref.read(userProvider.notifier).load(),
              child: const Text('Load user'),
            ),
          );
        }

        return Column(
          children: [
            Text(user.name),
            ElevatedButton(
              onPressed: () => ref.read(userProvider.notifier).retry(),
              child: const Text('Retry'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $e'),
            ElevatedButton(
              onPressed: () => ref.read(userProvider.notifier).retry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### AutoDispose version (recommended for screens)

```dart
class UserController extends AutoDisposeNotifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() => const AsyncData(null);

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => fetchUser());
  }

  Future<void> retry() async => load();

  void clear() => state = const AsyncData(null);
}

final userProvider = AutoDisposeNotifierProvider<UserController, AsyncValue<User?>>(
  UserController.new,
);
```

## 4) Always use `AsyncValue` in UI

Never manually track loading/error flags.

### Example

```dart
final userAsync = ref.watch(userProvider);

return userAsync.when(
  data: (user) => Text(user.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

---

## 5) Use `watch` vs `read` correctly

Rule:

* `watch` → rebuilds UI
* `read` → one-time access

### Example

```dart
final user = ref.watch(userProvider);

ElevatedButton(
  onPressed: () {
    ref.read(counterProvider.notifier).increment();
  },
  child: const Text("Increment"),
);
```

---

## 6) Keep providers pure (no UI side effects)

Do NOT:

* Show SnackBars in providers
* Navigate inside providers
* Use BuildContext inside providers

Instead use `ref.listen` inside widgets, **and only from `build`** (never in
`initState`). This keeps listeners tied to the widget lifecycle and avoids
stale subscriptions.

### Example

```dart
ref.listen(authProvider, (previous, next) {
  if (next is LoggedOut) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Logged out")));
  }
});
```

---

## 7) Fetch data on load in StatefulWidget

If a widget is **Stateful** and needs to fetch data on load, use a post-frame callback.

### Example

```dart
class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userProvider);
    });

    return userAsync.when(
      data: (u) => Text(u.name),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }
}
```

---

## 8) Use derived providers instead of duplicated state

Never store values that can be computed.

### Example

```dart
final totalPriceProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, item) => sum + item.price);
});
```

---

## 9) Use `select` to reduce rebuilds

```dart
final username = ref.watch(
  profileProvider.select((p) => p.username),
);
```

This prevents unnecessary rebuilds.

---

## 10) Use provider families for parameters

### Example

```dart
final userByIdProvider =
    FutureProvider.family<User, String>((ref, id) async {
  return fetchUserById(id);
});
```

Usage:

```dart
final userAsync = ref.watch(userByIdProvider(userId));
```

---

## 11) Use `Equatable` for Provider Params

When using `Provider.family` (or `FutureProvider.family`) with custom params,
make sure the param class implements `Equatable`. This prevents repeated
fetches caused by new object instances with identical values.

### Example

```dart
class AvailabilityParams extends Equatable {
  const AvailabilityParams({
    required this.providerId,
    required this.date,
  });

  final String providerId;
  final String date;

  @override
  List<Object?> get props => [providerId, date];
}
```

---

## 11.1) `AutoDisposeNotifier` vs `AutoDisposeFamilyNotifier`

If your provider is a family, the controller must extend the **family** base
class. Do not use `AutoDisposeNotifier` with a `.family` provider.

### Correct (Family)

```dart
class ListParams {
  const ListParams({required this.id});
  final int id;
}

class ListState {
  const ListState();
}

class ListController
    extends AutoDisposeFamilyNotifier<ListState, ListParams> {
  @override
  ListState build(ListParams params) {
    // use params.id
    return const ListState();
  }
}

final listProvider = AutoDisposeNotifierProviderFamily<ListController, ListState, ListParams>(
  ListController.new,
);
```

### Incorrect (Not Family)

```dart
class ListController extends AutoDisposeNotifier<ListState> {
  @override
  ListState build(ListParams params) => const ListState();
}
```

---

## 12) Pagination State Shape (Recommended)

For paginated screens, prefer a **state object** that holds:
- The pagination response (items + cursor)
- A single `AsyncValue<void>` status for loading/error transitions

Avoid storing `AsyncValue<CursorPaginationResponse<T>>` directly. This makes it
hard to show "loading more" indicators and can hide background loading.

### Suggested Pattern

```dart
class PaginationUiState<T> {
  const PaginationUiState({
    required this.response,
    this.status = const AsyncValue.data(null),
  });

  final CursorPaginationResponse<T> response;
  final AsyncValue<void> status;
}
```
