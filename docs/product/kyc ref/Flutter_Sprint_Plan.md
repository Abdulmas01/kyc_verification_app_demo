Status: Execution Plan

# Flutter Sprint Plan (Milestone-Based)

Purpose: keep implementation focused, complete, and edge‑case aware.
This plan mirrors the Flutter milestones in `Thesis_Milestone_Checkpoints.md`.

---

## Sprint 0 — Readiness (½ day)

Suggested timebox: 3–4 hours

Goal: prevent rework by confirming backend + model assumptions.

- [ ] Architecture confirmed: server‑authoritative decisions
- [ ] API contract confirmed: start → upload → poll
- [ ] Backend endpoint reachable on device (local tunnel or test host)
- [ ] Doc quality TFLite available
- [ ] Test images prepared (clean, blurry, glare, dark)

Exit criteria: we can hit `/verify/start/` from the device and get a token.

---

## Sprint 1 — F1 Setup & App Skeleton (1 day)

Suggested timebox: 6–8 hours

Goal: stable app shell on device.

Tasks
- [ ] Create Flutter project structure (per DOC3)
- [ ] Add dependencies (camera, mlkit, dio, tflite_flutter, riverpod)
- [ ] Android/iOS permissions set
- [ ] Basic routing wired (home → document → selfie → processing → result)
- [ ] Runs on physical Android device

Edge cases
- [ ] Permission denied flow (show CTA to enable)
- [ ] Device without camera (graceful error)

Exit criteria: app launches, routes work, camera permission prompt appears.

---

## Sprint 2 — F2 Document Capture UX (1–2 days)

Suggested timebox: 6–12 hours

Goal: capture a clean, normalized document image.

Tasks
- [ ] Camera preview renders reliably
- [ ] Document overlay drawn (ID card aspect ratio)
- [ ] ML Kit boundary detection integrated
- [ ] Perspective warp applied
- [ ] Auto‑capture when quality GOOD for 1.5s
- [ ] Store encrypted document image locally

Edge cases
- [ ] No document detected (show guidance)
- [ ] Corners unordered (fix ordering)
- [ ] Glare/blur/dark feedback

Exit criteria: saved normalized document image from live camera.

---

## Sprint 3 — F3 Quality Feedback (UX‑Only) (1 day)

Suggested timebox: 4–6 hours

Goal: real‑time doc quality guidance without jank.

Tasks
- [ ] TFLite doc_quality model loads at startup
- [ ] Frame skipping (every 3rd frame)
- [ ] Live quality label + message UI
- [ ] Capture gating based on GOOD quality

Edge cases
- [ ] Low‑end device performance (reduce frame rate)
- [ ] Model load failure (fallback messaging)

Exit criteria: stable real‑time quality feedback on device.

---

## Sprint 4 — F4 Selfie + Liveness UX (1–2 days)

Suggested timebox: 6–12 hours

Goal: capture a good selfie with active liveness prompts.

Tasks
- [ ] Front camera preview
- [ ] ML Kit face detection
- [ ] Blink + head‑turn prompts
- [ ] Challenge completion tracked (UX only)
- [ ] Best selfie frame captured and encrypted

Edge cases
- [ ] Multiple faces in frame
- [ ] Face too small / out of frame
- [ ] Glasses or low light (prompt guidance)

Exit criteria: selfie image captured with challenge completion state.

---

## Sprint 5 — F5 Backend Integration (1 day)

Suggested timebox: 4–6 hours

Goal: end‑to‑end flow with server‑authoritative decision.

Tasks
- [ ] POST `/verify/start/` works
- [ ] POST `/verify/upload/` with doc + selfie
- [ ] GET `/verify/{session_id}/` polling
- [ ] Error handling and retry UI

Edge cases
- [ ] Network loss during upload
- [ ] Backend timeout (show retry)
- [ ] Invalid session token (restart flow)

Exit criteria: full flow returns decision on device.

---

## Sprint 6 — F6 Result UI (½–1 day)

Suggested timebox: 3–6 hours

Goal: clear decision display.

Tasks
- [ ] Decision UI (ACCEPT/REJECT/MANUAL_REVIEW)
- [ ] Reason codes as chips
- [ ] Risk score optional (thesis demo)
- [ ] “Done” resets flow

Edge cases
- [ ] Missing reason codes
- [ ] Unknown decision value

Exit criteria: result screen correct for all outcomes.

---

## Sprint 7 — F7 Reliability & Polish (1 day)

Suggested timebox: 4–8 hours

Goal: stable demo on real device.

Tasks
- [ ] Background/foreground handling
- [ ] UI jank removal (move heavy work off UI thread)
- [ ] Graceful handling of permission changes mid‑flow
- [ ] Basic logging for failures

Exit criteria: demo runs end‑to‑end twice in a row without failure.

---

## Final Acceptance Checklist

- [ ] Document capture works in varied lighting
- [ ] Selfie capture completes with liveness prompts
- [ ] Backend decision shows in < 10s end‑to‑end
- [ ] Manual review path displays correctly
- [ ] No crashes across two full runs
