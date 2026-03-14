# Widget and Screen Coding Guidelines

This document captures the widget and screen conventions we want across the app.

## Folder Structure and Content
- Keep feature code under `lib/core/features/<feature>/`.
- Split by layer: `data/`, `domain/`, `presentation/`.
- `data/` contains `data_sources/`, `repositories/`, `services/`.
- `domain/` contains models, enums, and business rules.
- `presentation/` contains screens, controllers, and UI state.
- For multi-step flows, keep step screens under
  `lib/core/features/<feature>/presentation/steps/<flow_name>/`.
- For role-based features (provider/customer/admin), prefer a single feature
  with role subfolders:
  - `presentation/screens/shared|provider|customer|admin/`
  - `presentation/widgets/shared|provider|customer|admin/`
  - `presentation/controllers/shared|provider|customer|admin/`
- Shared UI widgets belong in `lib/core/widget/`.
- Shared extensions belong in `lib/core/extension/`.
- Shared networking goes in `lib/core/network/`.

## Context Usage
- Do not call `Theme.of(context).textTheme` directly.
- Use the context extension helpers instead (from `lib/core/extension/`).

## State, Policy, and Validation
- Split policy/validation from UI. Keep validation logic out of widget build methods.
- Use Riverpod to store UI variables when there are more than two mutable UI fields.
- Prefer `AsyncValue` + `AsyncNotifier`/`AsyncNotifierProvider` for simple fetch
  flows. Avoid custom UI event enums and `consumeEvent` unless they add real
  behavior you can't express with `AsyncValue`.
- If API calls and UI mutations are tightly coupled (e.g., paginated list + item updates), keep them in a single notifier file.
- If they are independent, split into separate notifiers.
- For screens with both UI-only state and API state, use two providers: one UI state notifier and one API notifier that owns network calls.
- For screens with both UI-only state and API state, use two providers: one UI state notifier and one API notifier that owns network calls.
- The detailed split criteria and examples live in `docs/state_provider_split_guidelines.md`.

## Design System (Tokens)
- No hard-coded values in UI.
- Always check existing theming first and reuse it by default.
- If a spacing value is needed, add it to `AppSpacing`.
- If a text style is needed, add it to the text theme extension in `lib/core/extension/`.
- If a color, radius, or other design token is needed, add it to theming instead of inlining.

## Forms and Models
- Represent each form with a raw form model that you mutate.
- Build request payloads via a mapper (do not mutate maps directly in UI).
- For edit flows, use `ValueMerge` to merge edited fields (same approach as patch updates).
- Every model should include a `factory` for test data.
- If a model is sent to the backend, it must implement a `toPayload()` mapper.
- If a service/repository/data source method takes multiple parameters, prefer a single model class to avoid changes in multiple layers.
- Make model fields nullable by default. Handle missing data safely in UI with optional fallbacks so backend changes do not break the app.

## Routing
- Every screen must define a static `path` string, even if we are not yet using named routes or GoRouter.

## Riverpod Naming
- Use consistent naming when reading provider values.
- If the provider holds UI state, name the local variable with `UiState` (e.g., `final uiState = ref.watch(myProvider);`).
- If the provider is a notifier, include `Notifier` in the variable holding the notifier (e.g., `final authNotifier = ref.read(authNotifierProvider.notifier);`).

## Riverpod Provider Params
- For `Provider.family` params, ensure the param model implements `Equatable` to avoid repeated fetches from unstable equality.

## Constructors
- Prefer named constructors over positional constructors when there are multiple parameters or reduced readability.

## API DTO Naming
- Response models should end with `Response`.
- Request models should end with `Request` when needed.

## Database Structure
- Organize database code under `lib/core/database/` by engine (e.g., `hive/`).
- Keep constants in a single file (`hive_constants.dart`) and reference them everywhere.
- For Hive, always use `HiveTypeIds` for `typeId`. Do not hardcode type IDs inside model adapters.
- Prefer generated Hive adapters (`@HiveType`) over manual adapters.

## Mapping for Clean UI
- If UI elements can be represented as an array, put them in a list and `map` to widgets.
- Prefer list-driven rendering over repeated widget blocks for cleaner code.

## Reuse Before Creating New Widgets
- Check `lib/core/widget/` first for existing reusable widgets.
- Prefer reusing `info_banner_card_widget.dart` and `profile_picture_widget.dart` where appropriate.
- If a common UI pattern shows up in more than one screen, promote it into `lib/core/widget/`.
- For paginated UIs, use the shared widgets in `lib/core/widget/pagination/` instead of re-implementing scroll logic.

## Screen Structure and Private Widgets
- Keep screens readable by extracting sections into private widgets inside the same file.
- Use private widget classes: `_HeaderSection`, `_Body`, `_Footer`, etc.
- Prefer small focused widgets over large build methods.
- For step-based UIs (KYC, onboarding, etc.), avoid hardcoded step counts or
  progress percentages. Always compute progress from `currentStep` and
  `totalSteps`, ideally via a shared step config for the flow.

## Data, Models, and Mapping
- If a UI element represents a data entity, define a model class.
- Map API/data objects into models before rendering.
- Avoid passing raw `Map<String, dynamic>` into widgets.

## No Magic Strings
- Do not inline repeated strings or keys.
- Use enums or constants for values used across the codebase.
- Do not create separate key classes for model field names (e.g., `FcmMessageKeys`) unless the keys can be represented as an enum.
- For simple model parsing (e.g., `title`, `body`), inline the string keys directly in the map access. Do not add extra static constants unless it truly reduces repetition.

## Enums for Stable Values
- Use enums for fixed options (e.g., status, type, category, role).
- Convert enums to display strings in one place (extensions or mapper functions).
- Use `EnumHelper` (see `enum_helper_function.extention.dart`) for consistent
  casing/label conversions instead of ad-hoc string logic in UI files.
- Prefer enum extensions for UI mappings (labels, icons, tones).
- Avoid adding `extension on <StateClass>` for UI behavior; keep that logic
  inside the widget class or in helper classes/services.

## Example Pattern
```dart
class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          _HeaderSection(),
          _WalletSection(),
          _TransactionListSection(),
        ],
      ),
    );
  }
}



enum ExampleStatus { active, archived }

```

## Notes
- Keep UI composition in the screen or widget folder of that feature file if it is screen-specific.
- Only move to `lib/core/widget/` when it is reused across screens.
