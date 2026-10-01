# Mobile Model Execution Modes

Status: Future-facing draft for backend alignment

Purpose: document the possible mobile-vs-backend execution modes for liveness and face embedding before we commit to more implementation work.

Related docs:

- `docs/product/Verydent_Flutter_SDK_Plan.md`
- `docs/product/SDK_Guidelines_Adaptation.md`

---

## 1. Current Position

As of August 14, 2026:

- the thesis app supports guided document capture and selfie/liveness flow
- the mobile liveness model can run on-device in shadow mode
- the current liveness stage success is still driven by guided challenge logic and face analysis flow
- backend verification remains the trusted final decision path

This document does not change that behavior.

It only records the future options we may support after backend alignment.

---

## 2. Core Product Question

If we add more mobile models such as:

- mobile liveness
- mobile face embedding
- mobile document quality

then we must decide:

- what runs on device
- what still requires backend confirmation
- what customers are allowed to use without our backend
- how pricing and entitlement should work

This is both a technical and business-boundary decision.

---

## 3. Recommended Execution Modes

We should think in modes, not scattered booleans.

### A. `guidance`

Meaning:

- mobile uses camera guidance and UX only
- models may be off or advisory only
- backend remains the only real verifier

Use cases:

- starter plan
- thesis/demo environments
- customers who want hosted verification only

### B. `shadow`

Meaning:

- mobile runs local models
- SDK returns local model outputs for telemetry/debug/reporting
- backend still makes the final decision

Use cases:

- model benchmarking
- safe rollout
- thesis comparison between mobile and backend outputs

This is the safest first production mode for mobile models.

### C. `hybrid`

Meaning:

- mobile runs liveness and/or face embedding first
- backend receives mobile outputs plus captured assets
- backend confirms or overrides the decision

Use cases:

- cost reduction
- faster UX
- bandwidth optimization
- stronger progressive validation

Recommended future default for paid SDK usage.

### D. `authoritative`

Meaning:

- mobile models are allowed to make the primary decision for a step
- backend may be optional or fallback-only

Use cases:

- enterprise/offline deployments
- regulated field devices with intermittent connectivity
- premium licensed customers

This should not be the default general SDK mode.

---

## 4. Recommended Product Boundary

Recommended default business rule:

- standard SDK customers should use `hybrid` or `shadow`
- backend confirmation should remain required by default
- fully mobile authoritative mode should be a separately licensed capability

Why:

- once models ship to devices, customers can reduce backend usage
- full offline authority weakens the recurring backend value if exposed too broadly
- backend still provides audit, policy enforcement, workflow control, tenant logic, billing hooks, and final signed outcomes

So the long-term product should not be:

- “here is the entire pipeline, use it forever without us”

It should be:

- “here is a mobile-first SDK with controlled execution modes, with backend confirmation as the default contract”

---

## 5. Future SDK Config Shape

Do not implement this yet without backend confirmation.

Suggested direction:

```dart
class VerydentKycExecutionConfig {
  final KycExecutionMode mode;
  final bool enableMobileLiveness;
  final bool enableMobileFaceEmbedding;
  final bool enableMobileDocumentQuality;
  final bool requireBackendConfirmation;
  final bool allowOfflineAuthoritativeMode;
}
```

Recommended mode enum:

```dart
enum KycExecutionMode {
  guidance,
  shadow,
  hybrid,
  authoritative,
}
```

Important rule:

- mode should be the primary contract
- individual feature flags should refine mode behavior, not replace it

---

## 6. Liveness Result Contract Direction

When a model runs, the SDK should never collapse outcomes into a vague boolean.

We need clear result categories such as:

- `passed`
- `failed`
- `runtimeFailed`
- `needsBackendReview`

And clear reason codes such as:

- `spoofSuspected`
- `modelUnavailable`
- `faceNotFound`
- `multipleFaces`
- `timedOut`
- `needsBackendReview`

Important rule:

- `runtimeFailed` must never be treated as `spoofSuspected`

This distinction is critical for any future authoritative mode.

---

## 7. Face Embedding Direction

If a mobile face embedding model is added later, the likely future flow is:

1. capture selfie
2. run mobile liveness
3. run mobile face embedding
4. package outputs and metadata
5. decide whether backend confirmation is required based on execution mode

Recommended near-term stance:

- mobile embedding can be added for `shadow` and `hybrid` first
- do not jump straight to fully mobile identity match authority

Reasons:

- threshold policy must be aligned with backend
- preprocessing parity must be confirmed
- drift and device variation must be measured
- customer entitlement and pricing must be clear first

---

## 8. Pricing and Entitlement Direction

This is a product note, not a final pricing decision.

Suggested direction:

### Standard plan

- guided capture
- backend verification
- optional shadow mobile models
- backend confirmation required

### Hybrid plan

- mobile liveness and/or embedding enabled
- backend still confirms final decision
- lower backend workload and possibly lower per-verification cost

### Enterprise / offline-authoritative plan

- controlled mobile-only authority
- stronger entitlement rules
- signed model packs or version-locked model bundles
- contract-level restrictions

This protects the backend business while still allowing premium mobile capability.

---

## 9. What We Should Confirm With Backend First

Before implementing more of this, confirm:

1. Whether NestJS wants mobile model outputs uploaded as first-class inputs.
2. Whether backend will accept mobile liveness and mobile embedding as advisory only or as weighted signals.
3. Whether offline or mobile-authoritative mode is allowed at all.
4. Whether plan entitlements should control execution mode.
5. Whether backend wants signed model/version metadata for audit and fraud review.
6. Whether tenant configuration can enable/disable these capabilities safely.

---

## 10. Recommendation

For now:

- keep the thesis app and current implementation focused on `shadow` and backend-confirmed flow
- keep documenting mobile-authoritative ideas, but do not productize them yet
- review this with backend before adding mobile face embedding or broader offline capability

Recommended next implementation step after backend confirmation:

- wire mobile liveness outputs and later face-embedding outputs into one shared SDK result contract
- let backend decide how much authority those outputs actually carry

---

## 11. Production Liveness Capture Hardening

### Current implementation boundary

The Flutter flow currently performs a deterministic ML Kit facial-action
sequence:

1. blink;
2. turn left;
3. turn right; and
4. look straight before capture.

This is a **facial-action capture challenge**, not a replay-resistant active
liveness decision. The sequence is fixed, the final still is accepted when ML
Kit finds at least one face, and the optional LiteRT liveness model runs in
fail-open shadow mode. Flutter uploads the document and selfie images; it does
not upload server-issued challenge proof or a challenge transcript. Backend
passive PAD remains authoritative.

A controlled prerecorded-video replay on 29 August 2026 completed the mobile
challenge and reached backend upload. The complete pipeline rejected that
attempt, but backend face acquisition failed before passive PAD produced a
usable attack score. Therefore, the observation demonstrates a mobile challenge
weakness and system-level rejection; it does not demonstrate mobile or backend
PAD detection of that replay.

### Minimum Flutter work before customer production

Treat these as production gates, not thesis blockers:

1. Replace `Liveness complete` with wording such as `Selfie captured;
   verification pending` until an authoritative decision is returned.
2. Validate the final still independently of the streamed challenge frames:
   require exactly one face, an acceptable face size, near-frontal pose,
   sufficient sharpness, and acceptable exposure.
3. Reset the challenge if the tracked face disappears, changes identity, or is
   replaced between challenge steps and final capture. ML Kit tracking can
   support continuity checks, but tracking alone is not presentation-attack
   detection.
4. Consume a short, randomized challenge issued for the verification session
   instead of hard-coding one public sequence. The challenge must expire and
   must not be reusable across sessions.
5. Bind the ordered action observations and final capture to the challenge ID,
   session nonce, timestamps, app/model versions, and final-asset hash. Upload a
   bounded transcript for backend validation; do not treat a client-generated
   success boolean as trusted evidence.
6. Keep mobile PAD advisory until replay, print, screen, device, demographic,
   and runtime-failure evaluation supports a stricter execution mode. Missing
   model assets, invalid challenge proof, or runtime failure must never become a
   liveness pass.
7. Preserve stage-specific outcomes: `challengeCompleted`,
   `finalFaceAccepted`, `mobilePadScore`, `backendFaceAcquired`,
   `backendPadScore`, and `finalDecision`. This prevents face-acquisition failure
   from being reported as spoof classification.

### Backend and product dependencies

Flutter cannot make the capture challenge trustworthy by itself. NestJS/Django
product work is required to:

- issue and expire session-bound randomized challenges;
- validate challenge transcripts and asset binding;
- enforce replay/rate-limit policy and record audit evidence;
- verify app and device integrity where supported; and
- retain authoritative passive PAD and policy decisions until mobile authority
  is explicitly approved.

For higher-assurance customer deployments, evaluate a dedicated active-liveness
or PAD implementation rather than presenting ML Kit facial attributes alone as
proof of liveness.

### Required production evaluation

Evaluate each stage separately with consented, access-controlled evidence:

- genuine users across supported device tiers and lighting conditions;
- printed photographs;
- frontal and profile screen replays;
- prerecorded video replays that contain the prompted actions;
- multiple-face and face-replacement attempts;
- blurred, dark, overexposed, and interrupted captures; and
- missing-model, timeout, offline, and backend-error paths.

Report whether each attempt passed the mobile challenge, passed final-face
quality, reached mobile/backend PAD, crossed its registered threshold, and was
accepted or rejected overall. Do not call the production control
replay-resistant until this evaluation supports that claim.
