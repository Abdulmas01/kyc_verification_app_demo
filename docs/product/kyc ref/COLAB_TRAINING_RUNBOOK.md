Status: Execution Plan

# Colab Training Runbook (Face + Liveness + Matrix)

This runbook is the canonical execution flow for Colab training artifacts used by Flutter/backend integration.

## 1) Drive Layout (Required)

Use this exact structure under Google Drive:

```text
MyDrive/kyc_thesis/
  data/
    document_quality/
    face/
    liveness/celeba_spoof/
      train/{live,spoof}
      val/{live,spoof}
      test/{live,spoof}
  experiments/
    doc_quality/
    face/
    liveness/
  models/
    exports/
  reports/
    comparison_matrix.csv
```

## 2) One-Time Setup in Colab

```bash
!pip install -q torch torchvision timm scikit-learn onnx onnxruntime
```

Mount Drive:

```python
from google.colab import drive
drive.mount('/content/drive')
```

## 3) Face Training (existing notebook)

Use notebook:
- `docs/product/kyc ref/KYC_02_Face_Embedding.ipynb`

After each face run, append one row to matrix using this cell:

```python
import csv, datetime
from pathlib import Path

MATRIX = Path('/content/drive/MyDrive/kyc_thesis/reports/comparison_matrix.csv')
MATRIX.parent.mkdir(parents=True, exist_ok=True)
if not MATRIX.exists():
    MATRIX.write_text('timestamp_utc,task,run_id,variant,dataset_train,dataset_eval,model_name,epochs,batch_size,img_size,seed,accuracy,f1,auc,eer,apcer,bpcer,acer,latency_ms,model_size_mb,artifact_dir,notes\n')

row = {
    'timestamp_utc': datetime.datetime.utcnow().replace(microsecond=0).isoformat() + 'Z',
    'task': 'face',
    'run_id': RUN_ID,
    'variant': 'fp32_baseline',
    'dataset_train': 'vggface2_pretrained_or_finetune_set',
    'dataset_eval': 'lfw',
    'model_name': 'mobilefacenet',
    'epochs': EPOCHS,
    'batch_size': BATCH_SIZE,
    'img_size': 112,
    'seed': SEED,
    'eer': f'{EER:.6f}',
    'model_size_mb': f'{MODEL_SIZE_MB:.4f}',
    'artifact_dir': str(EXPORT_DIR),
    'notes': 'face embedding run'
}

with MATRIX.open('a', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=[
        'timestamp_utc','task','run_id','variant','dataset_train','dataset_eval','model_name','epochs','batch_size','img_size','seed',
        'accuracy','f1','auc','eer','apcer','bpcer','acer','latency_ms','model_size_mb','artifact_dir','notes'
    ])
    writer.writerow(row)
```

## 4) Liveness Training (new script)

Use script:
- `scripts/colab/train_liveness_celeba_spoof.py`

In Colab, run:

```bash
!python /content/kyc_verification_app_demo/scripts/colab/train_liveness_celeba_spoof.py \
  --drive-root /content/drive/MyDrive/kyc_thesis \
  --run-id liveness_run_001 \
  --epochs 12 \
  --batch-size 64 \
  --img-size 224 \
  --seed 42
```

This will save:
- `metrics.json`
- `history.json`
- `liveness.onnx`
- one row appended to `reports/comparison_matrix.csv`

## 5) Required Artifacts Before Flutter Device Testing

- Face ONNX export present in Drive.
- Liveness ONNX export present in Drive.
- Comparison matrix has rows for:
  - face baseline
  - liveness baseline
  - any INT8/distilled variant tested
- Each matrix row points to a real artifact folder in Drive.

## 6) Flutter/Backend Handoff Gate

Do not start full device testing until these are true:
- Backend can load latest face ONNX and liveness ONNX.
- `/verify/start -> /verify/upload -> /verify/{id}` returns decision with reason codes.
- Matrix entries are complete for reproducibility.
