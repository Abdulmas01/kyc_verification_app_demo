Status: Execution Plan

# Decision Matrix — Thesis vs Startup

This document records core architecture decisions to prevent drift across docs.

---

## Decision 1 — Authoritative Inference Location

**Options**
- A) Client-authoritative (mobile computes scores, server trusts them)
- B) Server-authoritative (mobile uploads images, server computes scores)

**Chosen (Thesis + V1 Startup):** B

**Why**
- Prevents payload tampering (security consistency)
- Reproducible evaluation (single authoritative pipeline)
- Clearer academic claims

**Implications**
- Requires upload and server compute
- Mobile remains UX-only (quality, framing, optional OCR pre-fill)

---

## Decision 2 — OCR Strategy

**Options**
- A) On-device ML Kit primary + server fallback
- B) Server Tesseract + MRZ primary, ML Kit UX-only

**Chosen (Thesis + V1 Startup):** B

**Why**
- Server-authoritative consistency
- Open-source reproducibility (Tesseract)
- Lower complexity in thesis pipeline

**Implications**
- Mobile OCR is optional and non-authoritative
- Server must handle OCR load

---

## Decision 3 — Active Liveness Challenges

**Options**
- A) Active challenge contributes to decision score
- B) Active challenge is UX-only; passive liveness is authoritative

**Chosen (Thesis + V1 Startup):** B

**Why**
- Keeps decision pipeline server-authoritative
- Avoids client tampering risk
- Still improves capture quality and UX

**Implications**
- Challenge success is not a hard reject signal
- Passive liveness model carries decision weight

---

## Decision 4 — Mobile ML Usage

**Options**
- A) Full on-device inference for all modules
- B) Mobile pre-screening only (quality, framing, optional OCR pre-fill)

**Chosen (Thesis + V1 Startup):** B

**Why**
- Thesis focus is model evaluation + security analysis
- Pre-screening reduces server failures without security risk

**Implications**
- Mobile models are UX helpers, not trusted signals

---

## Future Revisit Triggers (Startup Roadmap)

- Add strong attestation + fraud telemetry → reconsider selective client trust
- Server costs exceed budget → add optional client-side pre-filtering
- Real-world latency issues → consider hybrid optimization

