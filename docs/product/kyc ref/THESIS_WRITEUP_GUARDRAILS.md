Status: Thesis Canonical

# Thesis Write-up Guardrails (Progress Report Safe)

Use this file as the final filter before moving text into your main write-up.

## 1) Safe To Keep In Main Write-up
- Document quality model design, training, metrics, and compression results.
- Face embedding and liveness as core modules in-progress.
- Decision engine framing (baseline vs calibrated models).
- Server-authoritative architecture rationale at high level.
- Clear scope boundaries and limitations.

## 2) Keep Brief (1-3 lines only)
These are implementation controls, not core thesis contributions:
- AES encryption
- ECDSA signing
- Play Integrity API
- Django/Celery infrastructure

Rule: mention only as supporting implementation context inside methodology.
Do not create dedicated chapters/sections around these in the progress report.

## 3) Do NOT Add To Main Write-up (for now)
- Full cryptographic protocol analysis.
- Deep backend engineering details (queues, retries, infra internals).
- Product pricing, GTM, startup roadmap material.
- Extra modules outside approved objectives.
- Large statistical appendix unless requested by supervisor for final thesis.

## 4) For Progress Report Wording
Use this pattern:
- "Completed": only for measured and reported results.
- "In progress": face/liveness compression and mobile-vs-backend benchmarking.
- "Planned for final thesis": multi-seed statistical closure and expanded validation.

Avoid this pattern:
- Claiming cross-task compression findings as final before all tasks are measured.

## 5) Which Docs You SHOULD Reference When Writing
- `my_seminar_1.write_up.md`
- `CANONICAL_TRUTH.md`
- `SUPERVISOR_CRITIQUE_CLOSURE_CHECKLIST.md`
- `COLAB_ARTIFACT_ACCEPTANCE_CHECKLIST.md` (for evidence tracking, not copy-paste prose)

## 6) Which Docs You Should NOT Copy Into Main Write-up
- `DOC2_Backend_Django.md` (implementation depth)
- `DOC3_Flutter_App.md` (app build depth)
- `BACKEND_UPDATE_FROM_COLAB.md` (engineering handoff, not thesis narrative)
- any archived startup/product files

## 7) Defense Risk Hotspots (Likely Questions)
- Why cross-task compression claim is still partial at progress stage.
- Whether synthetic data generalizes to real capture conditions.
- Why Colab latency is not equivalent to device latency.
- How decision calibration quality will be validated at completion.

## 8) One-Line Decision Rule
If a paragraph does not strengthen a thesis objective, result, limitation, or evaluation claim, keep it out of the main write-up.
