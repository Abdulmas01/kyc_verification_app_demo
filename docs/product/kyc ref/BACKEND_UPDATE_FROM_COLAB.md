Status: Execution Plan

# Backend Update From Colab Outputs

This maps trained/exported artifacts to backend integration steps.

## 1) Source Of Truth Files To Reference In Review
Use these files when someone reviews the updated Colab pipeline:
- `docs/product/kyc ref/KYC_01_Document_Quality_Classifier.ipynb`
- `docs/product/kyc ref/KYC_02_Face_Embedding.ipynb`
- `docs/product/kyc ref/KYC_03_Liveness_Detection.ipynb`
- `docs/product/kyc ref/COLAB_ARTIFACT_ACCEPTANCE_CHECKLIST.md`
- `docs/product/kyc ref/CANONICAL_TRUTH.md`

## 2) Artifacts Backend Should Consume
From Drive, copy into backend model directory (example):
- `doc_quality_fp32.onnx` (authoritative server quality if needed)
- `face_embedder_fp32.onnx`
- `liveness_fp32.onnx`

Optional for benchmarking/ablation:
- INT8/distilled variants and associated metrics CSVs.

## 3) Backend Wiring Order
1. Load ONNX sessions at startup (singleton/global), do not reload per request.
2. Add model version tags from run folders (e.g., `face_run_id`, `liveness_run_id`) into response metadata/logs.
3. Validate inference I/O shapes against notebook export assumptions.
4. Run a smoke test through `start -> upload -> poll` with one known-good and one known-fail sample.

## 4) Minimal Validation Before API Testing
- [ ] Face ONNX loads and returns embedding vector successfully.
- [ ] Liveness ONNX loads and returns live/spoof logits successfully.
- [ ] Decision engine receives valid face/liveness scores and returns reason codes.
- [ ] Backend logs include model run IDs for traceability.

## 5) Keep Flutter In Sync
- Flutter uses `assets/models/doc_quality.tflite` for UX pre-screening.
- Backend remains authoritative for face and liveness decisions.
- Ensure model/version metadata shown in logs matches current Colab run IDs.
