# KYC Capture Runtime Notes

This document records implementation issues we hit in the Flutter KYC capture
flow, what they meant, and how the app currently handles them.

It is not thesis-specific. It exists so future app work, SDK extraction, and
bug triage do not repeat the same debugging from scratch.

## Scope

These notes apply to:

- document capture startup
- selfie capture startup
- on-device document quality inference
- Riverpod lifecycle safety in the KYC flow

## 1. Strict Model Contract Parsing

### Problem

The original Dart-side model contract loading was too permissive:

- malformed or missing contracts could silently fall back
- tensor layout could be guessed from shape
- document normalization was stored as a label string instead of numeric values

That made it possible for the app to keep running while preprocessing the model
input incorrectly.

### Fix

The app now uses strict contract parsing for document quality and liveness:

- explicit layout is required
- numeric normalization values are required
- dtype, channels, classes, and tensor shapes are validated
- runtime tensor signatures are checked against the contract
- incompatible models throw `ModelContractException`

### Why it matters

This improves correctness for both app testing and future SDK reuse. The ML
runtime now depends on a clear contract instead of hidden assumptions.

## 2. Background Isolate Contract Loading

### Problem

The document quality worker isolate originally loaded the contract with
`rootBundle`. In some permission/retry flows, that caused:

- `ModelContractException`
- `Binding has not yet been initialized`

This was a framework-bound asset loading issue inside the worker isolate.

### Fix

The main isolate now loads the contract JSON and passes the raw serialized
contract into the quality isolate.

The worker isolate only parses plain data. It does not call `rootBundle`.

### Why it matters

This makes background inference more stable and keeps the inference path more
framework-light, which is also a better fit for later SDK extraction.

## 3. Riverpod Lifecycle Writes

### Problem

Some provider writes were happening during widget lifecycle phases where
Riverpod does not allow mutation safely, especially:

- `build`
- `initState`

This caused runtime errors such as:

- `Tried to modify a provider while the widget tree was building`

### Fix

The KYC flow now avoids provider writes in unsafe lifecycle moments:

- processing completion navigation moved out of `build`
- startup provider writes in document/selfie steps moved to post-frame
- manual provider listeners are explicitly disposed

### Why it matters

This keeps UI state consistent and makes the flow easier to reason about and
test.

## 4. CameraX Surface Combination Failure on Android

### Problem

Some Android devices produced camera startup errors that looked like “back
camera unavailable,” but the real CameraX error was:

`No supported surface combination is found ... May be attempting to bind too many use cases`

This usually happened around permission dialogs, resume events, or retry flows.

### Root Cause

The document or selfie step could begin camera setup again while a previous
camera setup was still in progress or while previous use-cases were still
attached.

### Fix

The app now uses guarded camera initialization:

- only one camera setup can run at a time
- existing controllers are disposed before new setup starts
- retry and resume paths reuse the guarded init flow

### Why it matters

This reduces duplicate CameraX bindings and lowers the chance of startup races
on Android devices.

## 5. User-Facing Camera Error Messages

### Problem

Some technical camera startup failures were being surfaced as generic messages
like:

- `Unable to start the back camera`

That wording was misleading when the real issue was a temporary CameraX startup
conflict, not a missing camera.

### Fix

Camera exceptions are now mapped more carefully:

- permission denial stays a permission message
- surface/use-case conflicts prompt retry
- true no-camera cases report that clearly
- unknown failures still fall back to a generic camera-start error

### Current User-Facing Startup Conflict Message

`Camera session conflicted during startup. Retry camera to try again.`

## 6. Document Guidance Smoothing

### Problem

The document quality classifier can bounce between labels such as:

- `BLURRY`
- `DARK`
- `NO_DOCUMENT`

When that happened frame-to-frame, the on-screen guidance changed too quickly
and felt noisy.

### Fix

Document guidance now waits for a label to remain stable for a configured number
of frames before switching the user-facing message.

This smoothing only affects the displayed guidance. It does not change:

- raw model outputs
- debug logs
- thesis/debug metrics

### Current Guidance Style

- `GOOD` -> `Hold steady for capture.`
- `BLURRY` -> `Hold still for a clearer capture.`
- `GLARE` -> `Tilt slightly to reduce glare.`
- `DARK` -> `Move to better lighting.`
- `NO_DOCUMENT` -> `Place your ID fully inside the frame.`

## 7. Current Performance Interpretation

Recent document quality logs around `520–690ms` average inference time are slow
for a polished production UX, but still acceptable for the current prototype if:

- frame stride remains adaptive
- preview stays usable
- user guidance remains understandable

If performance becomes a product blocker later, the next low-risk levers are:

1. lower capture resolution further for document quality only
2. increase initial frame stride on slower devices
3. benchmark alternate model variants
4. move more preprocessing cost out of the hot path if needed

Avoid overengineering this until device testing shows the current UX is
insufficient.

## 8. Shared Camera Lifecycle Coordination

### Problem

As document capture and selfie/liveness became more interactive, camera control
started happening from many places:

- app lifecycle resume/pause
- retry buttons
- recapture flows
- auto-capture timers
- navigation pushes to the next step
- back navigation out of the current step

That made it easy to hit race conditions such as:

- `startImageStream was called while a camera was streaming images`
- dispose while a stream stop was still in flight
- stream restarts after a route was already covered or popped
- stale local `_isStreaming` flags drifting away from the real controller state

### Fix

The app now centralizes camera transition behavior in:

- `lib/core/camera/camera_lifecycle_coordinator.dart`

This coordinator is used by both:

- `document_capture_step.dart`
- `selfie_capture_step.dart`

It provides:

- queued start/stop/dispose transitions
- controller-state-based stream synchronization
- route-active tracking
- disposed-state guards
- best-effort error swallowing for teardown-only camera exceptions

### Current Design Rules

The coordinator exists so camera control follows a few explicit rules:

- only one camera transition chain runs at a time per screen
- the real controller state is treated as authoritative for stream status
- a hidden or popped route must not continue live frame work
- dispose should be idempotent
- teardown errors should be logged, not crash the capture flow

### Why it matters

This is the current foundation for stable capture behavior and future SDK
extraction.

Without this shared layer, document and selfie steps can slowly diverge and
re-introduce the same classes of camera bugs separately.

## 9. PopScope and Route Exit Behavior

### Problem

Even after lifecycle fixes, a capture screen can still become inactive because
of navigation, not because of app backgrounding:

- user presses back
- document pushes selfie
- selfie pushes processing

If camera work continues after that route is no longer the active surface, the
screen may still:

- process frames in the background
- restart a stream unexpectedly
- update state after the user already left that step

### Fix

Document and selfie screens now use `PopScope` to explicitly mark the route
inactive and pause camera work when the user exits the step.

They also mark the route inactive before pushing the next step and only restore
route activity when returning to an interactive capture state.

### Why it matters

Flutter widget mounting alone is not enough to model “this route is the active
camera owner right now.” Route-level coordination is part of the runtime
stability story.

## 10. Current Capture Route Behavior

The KYC capture flow now intentionally behaves as follows:

- document capture pauses live streaming before taking a picture
- successful document capture marks the route inactive before pushing selfie
- returning from selfie restores the document screen to its captured state
- document recapture explicitly re-enters the live guidance/inference state
- selfie capture pauses streaming before taking the final selfie
- selfie marks its route inactive before pushing processing
- back navigation from document or selfie pauses camera work immediately

This is the behavior to preserve during future cleanup or SDK extraction unless
product requirements change.

## Files Most Relevant To These Notes

- `lib/core/camera/camera_lifecycle_coordinator.dart`
- `lib/core/ml/document_quality_contract.dart`
- `lib/core/ml/liveness_shadow_contract.dart`
- `lib/core/ml/quality_isolate.dart`
- `lib/core/ml/quality_model.dart`
- `lib/features/kyc/presentation/steps/verification_flow/document_capture_step.dart`
- `lib/features/kyc/presentation/steps/verification_flow/selfie_capture_step.dart`
- `lib/features/kyc/presentation/steps/verification_flow/processing_step.dart`

## When To Update This Document

Update this file when we change:

- camera startup behavior
- isolate loading strategy
- contract parsing rules
- guidance smoothing behavior
- user-facing camera error handling
- measured performance assumptions used by the capture flow
