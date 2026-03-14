# Background Updates (Core)

This document describes the **generic background update system** located in
`lib/core/background_update/`. It is project‑agnostic and reusable across
features.

## What It Solves
- Non‑blocking updates (don’t block navigation)
- Retries with exponential backoff
- Persistence across app restarts

## Core Pieces
- `BackgroundUpdateTask` (model)
- `BackgroundUpdateStore` (persistent queue)
- `BackgroundUpdateService` (enqueue + flush)

## Usage Flow
1. Update local state immediately
2. Create a task with a unique `type` + `payload`
3. `runNow(...)` for immediate background attempt
4. `flush(...)` at app start or home entry

## Feature Example (School Update)
- Request model: `UpdateSchoolRequest`
- Controller: `SchoolUpdateController`
- Endpoint: `account/update` with `school_id`

## Retry Policy (Default)
- Exponential backoff, capped at 5 minutes
- Max attempts = 5

## Runbook
See `docs/runbook/background_updates.md` for the operational checklist and
platform limitations.
