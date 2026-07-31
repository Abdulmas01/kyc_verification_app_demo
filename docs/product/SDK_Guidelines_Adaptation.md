# SDK Guidelines Adaptation

Status: Draft

Purpose: explain how the current app widget and Riverpod guidelines should be applied when building the reusable Flutter SDK.

Related docs:

- `docs/WIDGET_GUIDELINES.md`
- `docs/riverpod_guidelines.md`
- `docs/product/Verydent_Flutter_SDK_Plan.md`

---

## 1. Summary

We should not throw away the current app guidelines for the SDK.

We should reuse the good architectural rules, but avoid copying app-specific folder paths and shared-app dependencies into the SDK package.

Use this rule:

- `use as-is` means the guideline should carry directly into the SDK.
- `adapt` means the idea is correct, but the SDK needs a package-friendly version.
- `app-only` means it should remain in the thesis/customer app and not define the SDK contract.

---

## 2. Decision Table

| Guideline Area | Decision | Notes |
|---|---|---|
| Layered feature split (`data/domain/presentation`) | use as-is | Strong fit for app and SDK |
| Multi-step flow organization | use as-is | Good fit for KYC flow packaging |
| Riverpod `Notifier` / `AutoDisposeNotifier` | use as-is | Good fit for capture and short-lived flows |
| UI-state vs API-state split | use as-is | Important for SDK maintainability |
| Neutral cancel token pattern | use as-is | Keeps Dio details isolated |
| Design tokens / no hardcoded UI values | adapt | SDK needs SDK-local theme/config tokens |
| Shared widget reuse rules | adapt | Reuse inside SDK package, not app-global `core/widget` |
| Context extension usage | adapt | SDK should not depend on app-specific extensions |
| Folder path `lib/core/features/...` | adapt | Use package `lib/src/...` structure instead |
| App routing conventions | app-only | SDK should not require app route ownership |
| App database conventions | app-only | SDK should avoid local persistence unless truly needed |
| Role-based app folders | app-only | SDK is not a full app surface with admin/customer roles |

---

## 3. Use As-Is

These guidelines transfer well to the SDK with little or no change.

### A. Layered feature separation

Keep:

- `data/`
- `domain/`
- `presentation/`

Why:

- keeps capture, networking, and UI concerns separated
- reduces refactor risk when backend contracts change
- makes testing easier

SDK version example:

```text
lib/src/
├── capture/
├── data/
├── domain/
├── presentation/
└── networking/
```

### B. Multi-step flow structure

The current step-flow idea is good for KYC.

Keep:

- document step
- selfie step
- liveness step
- processing step
- result handoff

This is a clean match for an SDK-guided verification flow.

### C. Riverpod notifier approach

Use:

- `Notifier`
- `AutoDisposeNotifier`

Why:

- capture flows are short-lived
- screens should release memory after exit
- notifier classes are easier to test and extract than widget-local state

### D. Split UI state from API state

Keep the current rule:

- one provider for UI-only state
- one provider for API/network state when needed

This is especially useful for:

- capture guidance text
- quality indicator state
- upload progress
- polling state
- cancellation and retry behavior

### E. Neutral cancellation pattern

Keep the current `RequestCancelToken` style.

Why:

- repository and service layers stay transport-agnostic
- SDK internals remain easier to mock
- future network changes remain localized

---

## 4. Adapt For SDK

These guidelines are correct in principle, but should be rewritten slightly for package use.

### A. Folder paths

Current app rule:

`lib/core/features/<feature>/...`

SDK version:

`lib/src/<module>/...`

Recommended SDK structure:

```text
lib/
├── verydent_kyc.dart
└── src/
    ├── capture/
    ├── models/
    ├── networking/
    ├── orchestration/
    ├── quality/
    └── widgets/
```

The architectural intent stays the same, but the package layout should not mirror app-only path conventions.

### B. Shared widgets

Current app rule:

shared widgets belong in `lib/core/widget/`

SDK version:

shared SDK widgets belong inside the SDK package, for example:

```text
lib/src/widgets/
```

Reason:

- the SDK must not depend on app-global widget libraries
- customer apps should consume the SDK as an isolated package

### C. Context extensions

Current app rule:

use app context extensions instead of direct `Theme.of(context).textTheme`

SDK version:

- use SDK-local theme helpers or extensions
- do not depend on app extensions from the thesis app

Reason:

- app extensions are not portable package contracts
- the SDK needs its own theming surface

### D. Design tokens

Current app rule:

no hardcoded UI values, use `AppSpacing`, theme, and extensions

SDK version:

no hardcoded UI values, but define SDK-owned tokens such as:

- `VerydentKycSpacing`
- `VerydentKycTheme`
- `VerydentKycColors`
- `VerydentKycStrings`

Reason:

- the principle is correct
- the token source must belong to the SDK, not the app

### E. Reuse-first rule

Current app rule:

check app shared widgets before creating new ones

SDK version:

- check SDK-local widgets first
- only depend on Flutter/framework-level primitives externally

Reason:

- package boundaries matter more than local app convenience

---

## 5. App-Only Guidelines

These guidelines should remain useful for the app, but should not define SDK internals.

### A. App routing ownership

The app guideline says every screen should define a static path.

That is fine in the thesis app, but the SDK should not force customer apps into one routing model.

SDK preference:

- expose launch widgets, flow widgets, or entry methods
- let host apps decide how navigation is wired

### B. App database conventions

The app’s database and Hive conventions are fine for the app.

The SDK should avoid local persistence unless there is a clear need such as:

- resumable flow recovery
- temporary encrypted capture staging

Even then, storage should remain internal and minimal.

### C. Role-based feature folders

The role-based folder split is useful for large apps with admin/provider/customer surfaces.

The SDK should not model itself this way unless it later grows multiple distinct operator surfaces, which is unlikely for V1.

---

## 6. Current KYC Flow Alignment

The current app already follows several strong patterns that we should preserve.

### Good matches

- `DocumentCaptureUiNotifier` is a good UI-state provider shape
- `VerificationApiNotifier` is a good short-lived API orchestration shape
- request models and repository seam are extractable
- cancellation handling already matches the Riverpod guideline direction

### Gaps to fix before extraction

- `SelfieCaptureStep` still uses local widget state for multiple mutable UI fields
- app-specific routing is still baked into step-to-step navigation
- some theming and widget reuse still depends on app-local abstractions
- direct backend assumptions still need to move behind the NestJS contract

---

## 7. Recommended Working Rules For The Team

When building the app:

- follow the existing widget guidelines normally
- keep using the existing app folder structure
- keep app shared widgets in app shared locations

When building SDK-ready KYC code:

- follow the Riverpod rules directly
- keep UI-state and API-state separate
- avoid app-global dependencies
- place reusable KYC widgets and tokens behind SDK-local abstractions
- avoid routing assumptions that customer apps cannot control

When extracting to the SDK package:

- move code only after it no longer depends on app routing, app theme helpers, or app shared widgets
- keep the public SDK surface small
- keep implementation details under `src/`

---

## 8. Immediate Refactor Targets

Before SDK extraction, the best alignment improvements are:

1. Convert selfie capture UI state to a Riverpod notifier.
2. Move KYC-specific reusable UI pieces behind feature-local or SDK-ready widgets.
3. Reduce direct dependency on app-level theme/widget helpers where practical.
4. Keep network orchestration behind request/response models and service boundaries.
5. Replace direct backend assumptions with NestJS-oriented session/bootstrap contracts.

---

## 9. Final Rule

The current guidelines are good foundations.

We should reuse their architectural discipline, not their app-specific file paths and app-only dependencies.

Short version:

- Riverpod guidance: mostly use as-is
- Widget architecture guidance: use the principles, adapt the paths and shared dependencies
- App routing/database/role structure: keep app-only unless the SDK later proves it needs them
