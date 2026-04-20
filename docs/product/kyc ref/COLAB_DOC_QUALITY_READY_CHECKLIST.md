Status: Execution Plan

# Colab Ready Checklist (Document Classification)

This checklist is for `KYC_01_Document_Quality_Classifier.ipynb` only.

## Canonical Targets
- Dataset size: 5,000 synthetic images (1,000 per class).
- Split: 70/15/15 train/validation/test.
- Classes: GOOD, BLURRY, GLARE, DARK, NO_DOCUMENT.
- Compression scope: FP32 baseline, INT8 PTQ, Distilled student.

## Drive Output Location
- Root: `MyDrive/kyc_thesis/`
- Dataset: `data/quality_dataset/`
- Checkpoints: `models/checkpoints/`
- Exports: `models/exports/`
- Results: `results/quality_model/`

## Required Artifacts Before Flutter Testing
- `doc_quality.tflite` present in Drive exports.
- `doc_quality_fp32.onnx` present in Drive exports.
- `compression_results.csv` generated.
- `compression_comparison.png` generated.
- `confusion_matrix.png` generated.
- `summary.json` generated.

## Matrix Comparison Requirement
Create or update one comparison table after each run with rows for:
- FP32 Baseline
- INT8 PTQ
- Distilled Student

Minimum columns to track:
- variant
- test accuracy
- macro F1
- model size (MB)
- latency mean (ms)
- latency p95 (ms)
- accuracy delta (pp)
- artifact path

## Handoff Gate
Move to device testing only when:
- `doc_quality.tflite` is copied into `assets/models/`.
- Flutter app loads model successfully at startup.
- Camera flow shows stable quality labels in real time.
- Auto-capture gating works for GOOD and blocks bad-quality frames.
