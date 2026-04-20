Status: Thesis Canonical (Locked on 2026-04-20)

# Thesis Canonical

This file is the single source of truth for thesis-track documentation in `docs/product/kyc ref`.

## Locked Values
- Dataset baseline: `5,000` synthetic document-quality images.
- Split baseline: `70/15/15` (train/validation/test).
- Liveness baseline: CelebA-Spoof for thesis training and primary reporting.
- OULU-NPU and CASIA-FASD: optional supplemental evaluation / future work unless explicitly reported with completed results.
- Compression scope for current thesis: INT8 post-training quantization + knowledge distillation.
- Structured pruning: out of current thesis scope (future work).
- Architecture: server-authoritative hybrid.
- Mobile inference role: UX and pre-screening only; final decision signals are computed server-side.
- Optional experimental track: on-device face/liveness inference is allowed for benchmarking and comparison, but remains non-authoritative.

## Claim Discipline
- Only completed empirical findings are written as findings.
- Any not-yet-measured claims must be labeled as `in progress` or `hypothesis pending validation`.
- Any mobile-vs-backend comparison claim must include explicit disagreement-rate evidence and latency comparison.

## API Contract (Unchanged)
- `POST /api/v1/verify/start/`
- `POST /api/v1/verify/upload/`
- `GET /api/v1/verify/{session_id}/`
