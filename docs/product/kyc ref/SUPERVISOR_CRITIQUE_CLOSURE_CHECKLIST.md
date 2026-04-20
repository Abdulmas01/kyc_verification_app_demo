Status: Thesis Canonical

# Supervisor Critique Closure Checklist

Date: 2026-04-20
Sources reviewed: `my_seminar_1.write_up.md`, `report_critism_by_supervisor.md`, `kyc_master_project_spec_FINAL.md`

## Major Revisions
- [x] Supervisor naming format corrected in seminar cover page.
- [x] Objectives rewritten as SMART-style with measurable targets and timeline ordering.
- [x] Central contribution language split into completed evidence vs in-progress evidence.
- [x] Synthetic dataset baseline synchronized to 5,000 with 70/15/15 split.
- [x] Liveness baseline synchronized to CelebA-Spoof; OULU/CASIA marked supplementary.
- [x] Compression scope synchronized to INT8 PTQ + knowledge distillation (no pruning in thesis scope).
- [x] Statistical rigor plan added (95% CI, multi-seed runs, significance tests).
- [x] INT8 size anomaly explanation added as current interpretation and flagged for deeper final-thesis analysis.

## Still Pending Experimental Evidence (Explicitly Queued)
- [ ] Complete and report face embedding compression results (FP32 vs INT8 vs distilled).
- [ ] Complete and report liveness compression results (FP32 vs INT8 vs distilled).
- [ ] Add real-world validation set results (synthetic-to-real gap).
- [ ] Add on-device latency benchmarks on target Android hardware.
- [ ] Expand cost-scaling analysis assumptions and calculations.

## Minor/Formatting Follow-ups
- [ ] Convert Equation 1 to proper equation-editor typesetting in final thesis manuscript.
- [ ] Ensure DOI formatting consistency across references during final formatting pass.
- [ ] Add/attach confusion matrix visualization to the result section package.
