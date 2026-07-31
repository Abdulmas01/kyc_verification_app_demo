# Verydent Flutter SDK Plan

Status: Draft for backend alignment

## 1. Purpose

Build a reusable Flutter SDK that lets customer apps launch a guided KYC flow without rebuilding:

- document capture
- selfie capture
- liveness guidance
- upload orchestration
- polling
- retries
- error handling

The SDK is a mobile client product surface, not a backend replacement.

---

## 2. Target Architecture

```text
Customer Flutter App
        ↓
Verydent Flutter SDK
        ↓ restricted session token
Customer / Verydent NestJS Backend
        ↓ service-to-service authentication
Django Verification Engine
```

### Boundary rule

NestJS is the product backend.

It owns:

- tenant management
- customer authentication
- API keys
- internal service tokens
- workflow selection
- webhook handling
- audit and reporting
- rate limits and billing rules
- final customer-facing API contracts

Django is the internal AI execution engine.

It owns:

- document analysis
- OCR execution
- face matching
- liveness scoring
- quality scoring
- raw AI processing results

The Flutter SDK owns:

- guided capture UX
- local image preparation
- optional on-device quality pre-checks
- upload progress
- polling
- retry and cancellation behavior
- stable mobile-facing result and error objects

### Non-negotiable security rule

The SDK must never contain:

- `INTERNAL_SERVICE_TOKEN`
- customer API keys
- tenant secrets
- direct privileged admin credentials

The SDK only receives a short-lived restricted session token created by NestJS.

---

## 3. Product Goal For V1

Keep V1 to one Flutter package, not multiple packages.

Recommended package:

```text
verydent_kyc_flutter/
├── lib/
│   ├── capture/
│   ├── models/
│   ├── networking/
│   ├── quality/
│   ├── widgets/
│   └── verydent_kyc.dart
├── example/
├── test/
└── pubspec.yaml
```

Why one package first:

- lower maintenance cost
- easier release management
- faster thesis-to-product extraction
- fewer cross-package versioning issues

Split into sub-packages later only if there is a real second use case.

---

## 4. Recommended Delivery Path

Do not pause the thesis app to build a polished SDK platform too early.

Recommended sequence:

1. Finish the thesis Flutter verification flow in the current app.
2. Refactor the KYC feature so capture, networking, and result mapping have SDK-safe boundaries.
3. Replace direct engine assumptions with NestJS session bootstrap assumptions.
4. Extract the stabilized modules into `verydent_kyc_flutter`.
5. Create a small example app that demonstrates customer integration.

This keeps momentum while avoiding premature package maintenance.

---

## 5. Public SDK API Shape

The SDK should expose one simple entry point first.

```dart
final result = await VerydentKyc.start(
  sessionToken: tokenFromBackend,
  workflowKey: 'document_face_liveness',
);
```

V1 can also support a configurable launcher:

```dart
final sdk = VerydentKyc(
  config: VerydentKycConfig(
    baseUrl: 'https://api.customer-domain.com',
    theme: VerydentKycTheme.standard(),
    enableLocalQualityCheck: true,
  ),
);

final result = await sdk.start(
  sessionToken: tokenFromBackend,
  workflowKey: 'document_face_liveness',
);
```

### Design rule

Keep the public API product-facing, not infrastructure-facing.

Good:

- `sessionToken`
- `workflowKey`
- `theme`
- `locale`
- `result`
- `errorCode`

Avoid leaking:

- Django endpoint details
- provider-specific score names
- internal pipeline step names
- raw internal auth headers

---

## 6. Configuration Model

The SDK should support configuration in three layers.

### A. Compile-time package defaults

Used inside the SDK for safe defaults:

- default polling interval
- default retry counts
- default timeout values
- default image compression settings

### B. App integration config

Provided by the customer app when the SDK is initialized:

- backend base URL
- theme or branding options
- localization overrides
- feature flags for optional UI behavior

Example:

```dart
class VerydentKycConfig {
  final String apiBaseUrl;
  final Duration uploadTimeout;
  final Duration pollingInterval;
  final bool enableLocalQualityCheck;
  final VerydentKycTheme? theme;
  final VerydentKycStrings? strings;
}
```

### C. Session-level config

Provided by NestJS during session creation or returned in bootstrap metadata:

- allowed workflow
- required capture steps
- document type constraints
- token expiry
- upload limits

Important rule:

tenant-specific business rules should come from NestJS, not hardcoded in the SDK.

---

## 7. Recommended Backend Contract

The SDK should integrate with NestJS, not directly with Django.

### Step 1: Create verification session

Customer app calls customer backend or your NestJS backend:

`POST /kyc/sessions`

Suggested response:

```json
{
  "sessionToken": "short-lived-mobile-token",
  "sessionId": "kyc_sess_123",
  "workflowKey": "document_face_liveness",
  "expiresAt": "2026-07-26T12:00:00Z",
  "sdkConfig": {
    "pollingIntervalMs": 1500,
    "maxPollingAttempts": 20,
    "allowedDocumentTypes": ["passport", "id_card", "drivers_license"]
  }
}
```

### Step 2: SDK uploads capture data

SDK sends document and selfie assets using the restricted session token.

Suggested mobile-facing endpoints:

- `POST /kyc/sdk/upload`
- `GET /kyc/sdk/sessions/{sessionId}`
- optional `POST /kyc/sdk/sessions/{sessionId}/cancel`

NestJS then talks to Django internally.

### Step 3: NestJS normalizes backend results

NestJS should map Django output to stable customer/mobile-facing contracts.

This is important because Django may evolve faster than the SDK.

---

## 8. Stable Result Model

The SDK should expose simple typed results.

Example:

```dart
class VerydentKycResult {
  final VerydentKycStatus status;
  final String sessionId;
  final String? verificationId;
  final VerydentKycDecision? decision;
  final List<VerydentKycIssue> issues;
}
```

Suggested statuses:

- `completed`
- `cancelled`
- `failed`
- `requiresReview`

Suggested decisions:

- `approved`
- `rejected`
- `manualReview`

Suggested mobile error codes:

- `camera_permission_denied`
- `document_capture_failed`
- `selfie_capture_failed`
- `quality_check_failed`
- `upload_failed`
- `network_timeout`
- `session_expired`
- `verification_processing_failed`
- `verification_cancelled`
- `unknown`

### Important rule

Error codes should be stable even if backend internals change.

---

## 9. Reusability Rules

To keep the SDK reusable, we should enforce these rules during extraction.

### Rule 1: No app-specific dependencies

Do not let the SDK depend on:

- app routing
- app auth state
- app home screens
- unrelated shared widgets
- app-local feature flags

### Rule 2: No tenant logic in Flutter

Do not hardcode:

- tenant IDs
- pricing plans
- workflow permissions
- approval thresholds
- customer-specific copy

### Rule 3: Theme and strings must be injectable

Branding should be customizable without forking SDK code.

Expose:

- colors
- button labels
- instruction strings
- progress messages
- support text

### Rule 4: Network layer must be replaceable

At minimum, the SDK network layer should be isolated behind one seam so we can:

- swap endpoints
- add auth headers
- mock API calls in tests
- evolve payloads safely

### Rule 5: Backend DTOs must be mapped at one boundary

Do not scatter response mapping across widgets, controllers, and repository layers.

One mapping seam reduces refactor cost.

---

## 10. Internal Package Structure

Recommended V1 structure:

```text
lib/
├── verydent_kyc.dart
├── src/
│   ├── capture/
│   │   ├── document/
│   │   ├── selfie/
│   │   └── liveness/
│   ├── models/
│   │   ├── config/
│   │   ├── result/
│   │   ├── error/
│   │   └── session/
│   ├── networking/
│   │   ├── api_client.dart
│   │   ├── dto/
│   │   ├── mappers/
│   │   └── session_service.dart
│   ├── quality/
│   │   ├── image_quality_service.dart
│   │   └── model_loader.dart
│   ├── widgets/
│   │   ├── flow/
│   │   ├── overlays/
│   │   └── feedback/
│   └── orchestration/
│       ├── kyc_flow_controller.dart
│       ├── upload_coordinator.dart
│       └── polling_coordinator.dart
```

### Public surface rule

Expose only what integrators need from `verydent_kyc.dart`.

Keep implementation details under `src/`.

---

## 11. How Current App Code Maps To The SDK

Current reusable candidates already exist in the app:

- KYC data source and repository patterns
- upload flow
- polling flow
- cancellation handling
- document capture UI pieces
- model loading and quality helpers

These should move toward the SDK.

Current app-specific or temporary pieces that should not define the SDK contract:

- direct Django endpoint assumptions
- hardcoded backend URL
- thesis-only screen flow wiring
- app-level navigation coupling

### Migration direction

Current app:

`lib/features/kyc/...`

Future SDK:

`packages/verydent_kyc_flutter/lib/src/...`

The thesis app can later consume the SDK like an external customer would.

---

## 12. Backend Responsibilities Needed Before Extraction

Before the SDK is production-ready, NestJS should provide:

- short-lived session token creation
- one stable mobile bootstrap contract
- one stable upload contract
- one stable status contract
- backend-side retry and idempotency rules
- normalized decision and error mapping from Django
- tenant-aware policy enforcement

### Strong recommendation

Do not let the SDK call Django directly in the final product model.

That would blur the tenant and security boundary and create refactor risk.

---

## 13. Reliability Expectations

The SDK should handle normal mobile failure modes well.

Required behaviors:

- safe cancellation
- upload progress reporting
- retry on transient network failure
- clear expired-session handling
- timeout handling
- recoverable processing state
- resumable polling where practical

Questions for backend alignment:

- Is upload idempotent for the same session?
- What happens if mobile retries after partial upload failure?
- Does NestJS return processing status while Django is still running?
- When does a session expire?

These answers affect the SDK retry policy.

---

## 14. Testing Strategy

The SDK should be maintainable only if testing is built in from the start.

Recommended test layers:

### Unit tests

- DTO mapping
- error mapping
- retry logic
- polling logic
- config parsing

### Widget tests

- capture guidance states
- progress states
- error states
- cancellation flow

### Integration tests

- happy path session start to result
- upload failure and retry
- session expiry
- manual review result

### Example app validation

Maintain an `example/` app inside the SDK repo to prove real integration still works.

---

## 15. Versioning And Release Plan

Use semantic versioning.

Suggested approach:

- `0.x` while contracts are still moving
- `1.0.0` after backend contracts are stable

Release triggers:

- API contract change
- public config change
- public result model change
- capture flow UX change that affects integrators

Recommended release hygiene:

- changelog per version
- migration notes for breaking changes
- example app updated with each release

---

## 16. Ownership And Maintenance Model

Treat the SDK as a product with clear ownership.

Minimum maintenance responsibilities:

- keep public API small
- review all backend contract changes for SDK impact
- maintain example app
- track supported Flutter and Dart versions
- monitor crash/error feedback from integrations
- maintain release notes

### Suggested ownership split

Flutter SDK owner:

- mobile UX
- package API
- tests
- package releases

NestJS owner:

- mobile bootstrap session contract
- token creation and validation
- tenant-aware policies
- normalized customer-facing responses

Django owner:

- AI model behavior
- internal verification pipeline
- score generation quality

---

## 17. Documentation Needed For Customers

When the SDK is extracted, it should ship with:

- quick-start guide
- backend integration guide for NestJS endpoints
- theming guide
- error code reference
- lifecycle and state diagram
- example integration app
- upgrade guide for breaking releases

---

## 18. Risks To Avoid

### High-risk mistakes

- putting tenant or API-key logic in Flutter
- exposing Django contracts directly to customers
- hardcoding one customer workflow in the SDK
- making public models mirror internal AI output too closely
- splitting into many packages before V1 demand exists

### Medium-risk mistakes

- inconsistent error mapping
- no example app
- no versioning discipline
- scattered DTO mapping

---

## 19. Recommended Next Steps

1. Confirm the proposed NestJS mobile contract with the backend team.
2. Freeze the session bootstrap response shape.
3. Refactor the current Flutter KYC flow so it no longer assumes direct Django ownership.
4. Identify which `lib/features/kyc` modules are extraction-ready.
5. Extract V1 into one package with an example app.

---

## 20. Working Assumptions To Validate

This plan assumes:

- NestJS is the only customer-facing backend
- Django is internal and not exposed as the mobile product API
- session tokens can be short-lived and scoped
- NestJS can normalize Django responses before returning them to mobile
- the thesis app remains the proving ground before package extraction

If any of these assumptions are wrong, update the boundary before extraction rather than patching around it in the SDK.
