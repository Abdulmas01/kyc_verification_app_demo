Status: Execution Plan

# Backend Sprint Plan (Milestone-Based)

Purpose: keep backend implementation aligned with the thesis scope and avoid reliability issues (memory, timeouts, queues).

---

## Sprint B0 — Readiness (½ day)

Suggested timebox: 3–4 hours

Goals
- [ ] Confirm server‑authoritative flow: start → upload → poll
- [ ] Confirm model files present (ONNX + decision_engine.pkl)
- [ ] Confirm OCR stack (Tesseract + MRZ) installed
- [ ] Decide runtime target (CPU‑only, no GPU)

Exit criteria: we can run a dry inference on one sample image.

---

## Sprint B1 — Project Skeleton + Auth (1 day)

Suggested timebox: 6–8 hours

Tasks
- [ ] Django project + apps (verification, accounts)
- [ ] API key auth working
- [ ] Base models + migrations
- [ ] Admin login works

Edge cases
- [ ] Missing/invalid API key → 401
- [ ] Expired session token → 404

Exit criteria: `/verify/start/` returns a session token.

---

## Sprint B2 — OCR Service (1 day)

Suggested timebox: 6–8 hours

Tasks
- [ ] Tesseract OCR service (server‑authoritative)
- [ ] MRZ parsing + field extraction
- [ ] `ocr_confidence` computation

Edge cases
- [ ] Low confidence OCR → manual review flag
- [ ] Missing MRZ → template extraction fallback
- [ ] Non‑ASCII characters in OCR output

Exit criteria: OCR returns fields + confidence on 3 test docs.

---

## Sprint B3 — Face + Liveness Inference (1–2 days)

Suggested timebox: 8–12 hours

Tasks
- [ ] Load ONNX Runtime models
- [ ] Face detection + alignment (server)
- [ ] Face embedding + similarity
- [ ] Passive liveness score

Edge cases
- [ ] No face detected → manual review
- [ ] Tiny face crop → low confidence penalty
- [ ] Liveness score below threshold → reject

Exit criteria: produces face_similarity + liveness_score for sample pairs.

---

## Sprint B4 — Decision Engine + Audit (1 day)

Suggested timebox: 6–8 hours

Tasks
- [ ] Decision engine integration (logistic/XGBoost)
- [ ] Reason code generation
- [ ] Audit logging

Edge cases
- [ ] Missing signals → manual review
- [ ] Hard reject overrides

Exit criteria: risk_score + decision returned consistently.

---

## Sprint B5 — API Endpoints (1 day)

Suggested timebox: 6–8 hours

Tasks
- [ ] POST `/verify/start/`
- [ ] POST `/verify/upload/` (doc + selfie)
- [ ] GET `/verify/{session_id}/`
- [ ] History + admin review queue

Edge cases
- [ ] Large uploads (size limits)
- [ ] Invalid file types
- [ ] Retry idempotency (same session)

Exit criteria: full flow works via curl.

---

## Sprint B6 — Reliability & Performance (1 day)

Suggested timebox: 6–8 hours

Tasks
- [ ] Timeouts + retry strategy
- [ ] Request size limits + compression
- [ ] Basic caching for models
- [ ] Structured logging

Edge cases
- [ ] Memory spikes during OCR or ONNX inference
- [ ] Concurrency load (2–5 parallel sessions)
- [ ] Slow I/O when saving images

Exit criteria: stable under small concurrent load.

---

## Engineering Notes (Memory + Stability)

**Memory pressure**
- Keep ONNX sessions global (don’t reload per request)
- Avoid storing full images in memory longer than needed
- Downscale before OCR (but keep MRZ readable)
- Use streaming uploads if images are large

**Timeouts**
- Set upload timeout higher than inference timeout
- Fail fast on invalid files
- Return 202 quickly, then process async if needed

**Observability**
- Log per‑step timings (OCR, face, liveness)
- Track memory usage every N requests
- Persist reason codes for audit

---

## Final Acceptance Checklist

- [ ] start → upload → poll returns decision under 10s
- [ ] OCR fields + confidence stable on real docs
- [ ] Face + liveness inference runs without crashes
- [ ] Manual review path reachable
- [ ] No memory spikes on 5 parallel requests
