Status: Execution Plan

# Colab Artifact Acceptance Checklist

Use this checklist before backend integration or supervisor review.

## A) Document Quality (KYC_01)
Expected source notebook:
- `docs/product/kyc ref/KYC_01_Document_Quality_Classifier.ipynb`

Required artifacts in Drive (`MyDrive/kyc_thesis/...`):
- `models/exports/doc_quality.tflite`
- `models/exports/doc_quality_fp32.onnx`
- `results/quality_model/confusion_matrix.png`
- `results/quality_model/compression_results.csv`
- `results/quality_model/compression_comparison.png`
- `results/quality_model/summary.json`

Checks:
- [ ] Split is 70/15/15 and dataset is 5,000 (or explicitly logged if changed).
- [ ] FP32, INT8, Distilled rows all present in compression results.
- [ ] Exported `doc_quality.tflite` is the model used by Flutter.

## B) Face Embedding (KYC_02)
Expected source notebook:
- `docs/product/kyc ref/KYC_02_Face_Embedding.ipynb`

Required artifacts in Drive (`MyDrive/kyc_thesis/experiments/face/<run_id>/`):
- `progress.json`
- `reports/per_seed_metrics.csv`
- `reports/summary_mean_std.csv`
- `reports/summary_ci95.csv`
- `reports/significance_paired_bootstrap.csv`
- `reports/eer_variant_bar.png`
- `exports/face_embedder_fp32.onnx`

Checks:
- [ ] Multi-seed metrics exist (`SEEDS=[42,43,44]` by default).
- [ ] FP32 vs INT8 present; Distilled present if training/checkpoint enabled.
- [ ] EER, AUC, latency, size tracked per variant.

## C) Liveness (KYC_03)
Expected source notebook:
- `docs/product/kyc ref/KYC_03_Liveness_Detection.ipynb`

Required artifacts in Drive (`MyDrive/kyc_thesis/experiments/liveness/<run_id>/`):
- `progress.json`
- `reports/per_seed_metrics.csv`
- `reports/summary_mean_std.csv`
- `reports/summary_ci95.csv`
- `reports/significance_mcnemar.csv`
- `reports/acer_variant_bar.png`
- `exports/liveness_fp32.onnx`

Checks:
- [ ] CelebA-Spoof split used as baseline (`train/val/test`).
- [ ] APCER, BPCER, ACER, AUC recorded.
- [ ] Multi-seed mean ± std and CI exported.

## D) Global Matrix + Traceability
Required file:
- `MyDrive/kyc_thesis/reports/comparison_matrix.csv`

Checks:
- [ ] New rows appended for each completed variant.
- [ ] Each row includes `artifact_path` pointing to run folder.
- [ ] `run_id` in matrix matches `progress.json` in artifact folder.
