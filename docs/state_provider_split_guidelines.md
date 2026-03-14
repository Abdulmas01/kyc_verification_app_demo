# UI vs API Provider Split Guidelines

Use this document when deciding whether to split UI state from API calls.

## When To Split (Recommended)
- The screen has local mutations (forms, filters, toggles, temporary lists) that should survive API refetches.
- UI state needs validation, mapping, or composition before calling the API.
- The API provider is reused across multiple screens.
- The UI state must be preserved while an API request is in-flight.

## When To Keep One Provider
- UI state is minimal (two fields or fewer) and always derived from API data.
- There is no local mutation, validation, or mapping.
- The provider is only used by one screen and is tightly coupled to the API response.

## Responsibilities By Provider

UI Provider (UI-only state)
- Owns local-only state and view models.
- Performs validation and mapping to request DTOs.
- May call the API provider and then mutate its own UI state based on the response.
- Must not perform network calls directly.

API Provider (network-only)
- Owns network calls and error/loading state.
- Does not hold UI-only state.
- Returns response models for UI provider to consume.

## Example Split

Availability screen
- `provider_availability_ui_controller.dart`: slots, toggles, local edits, validation.
- `provider_availability_controller.dart`: GET/PUT availability API calls.

Services screen
- `provider_services_controller.dart`: local list editing, validation, DTO mapping.
- `provider_skills_controller.dart`: GET/PUT provider skills API calls.
