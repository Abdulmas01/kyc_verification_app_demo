# Background Updates Runbook

This runbook documents a reusable pattern for **background (fire-and-forget)**
updates that should not block navigation or user flow. It is project-agnostic
and intended to be reused across features.

## When to Use
- The UI can proceed without waiting for the server.
- Local state should update immediately.
- Server update is best-effort and can retry later.

Examples:
- Updating user profile fields that don’t affect immediate navigation.
- Saving UI preferences.
- Recording analytics or non-critical settings.

## Pattern (Recommended)
1. **Update local state immediately** (provider/local store).
2. **Trigger the API update in background** (do not await).
3. **Listen for errors** and show a toast/snackbar if needed.
4. **Flush queued updates** on app start or home entry.

### Example (UI)
```dart
unawaited(ref.read(updateProvider.notifier).updateSomething(request));
```

### Example (Global Flush)
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(updateProvider.notifier).flushPending();
});
```

### Example (App Start)
```dart
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _didFlush = false;

  @override
  Widget build(BuildContext context) {
    if (!_didFlush) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_didFlush) return;
        _didFlush = true;
        ref.read(updateProvider.notifier).flushPending();
      });
    }
    return const Placeholder();
  }
}
```

### Example (Provider)
```dart
class UpdateController extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> update(UpdateRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.update(request);
    });
  }
}
```

## Error Handling
Use `ref.listen` **inside `build`** to show errors without blocking the flow:
```dart
ref.listen(updateProvider, (_, next) {
  next.whenOrNull(
    error: (e, _) => SnackbarApi().snackbar(context: context, text: "$e"),
  );
});
```

## Platform Reality Check (Flutter)
This pattern runs **only while the app is alive** (foreground or background
allowed by OS but still in memory). For *true background* execution:

- **Android**: use `WorkManager` or `ForegroundService` for guaranteed work.
- **iOS**: use `BGTaskScheduler` (BackgroundTasks) or silent push with limits.

If you don’t need true background execution, this in-app queue is enough.

## Retry Policy (Default)
- Exponential backoff starting at 2s.
- Max delay capped at 5 minutes.
- Max attempts default to 5 (per task).

You can adjust these in the background update service.

## Notes
- Do not put UI side-effects inside providers.
- Do not block navigation on background updates.
- Keep the update request model small and explicit.
