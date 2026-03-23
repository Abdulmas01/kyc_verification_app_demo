# Face Embedding Pipeline
## KYC Thesis — Face Embedding, LFW Evaluation, ONNX Export, Edge Cases

---

## What This Component Does

Takes two face images and answers one question:
**Is this the same person?**

```
Document photo (cropped from ID card)
        ↓
  Face Embedding Model
        ↓
  128-dim vector A

Selfie (captured live)
        ↓
  Face Embedding Model
        ↓
  128-dim vector B

cosine_similarity(A, B) → face_similarity score (0.0 – 1.0)
```

The score feeds the decision engine.
You do not train this model. You evaluate a pretrained one.

**Consistency note (thesis + deployment):**
The same pretrained model is used for both:
- Mobile UX (TFLite) for fast feedback
- Backend (ONNX) for authoritative decisions

---

## Model Choice (Baseline + Mobile Option)

| Model | Size | Accuracy (LFW) | Speed | Suitable |
|---|---|---|---|---|
| ArcFace (ResNet100) | 250MB | 99.8% | Slow | ❌ Too large |
| FaceNet (Inception) | 95MB | 99.6% | Medium | ❌ Too large |
| MobileFaceNet | 4MB | 99.5% | Fast | ✅ |
| InceptionResnetV1 (VGGFace2) | ~95MB | 99.6% | Medium | ✅ baseline |
| MobileNetV2-face | 14MB | 98.9% | Fast | ✅ acceptable |

MobileFaceNet gives near-identical accuracy to the large models
at 4MB. This is the compression argument for your thesis —
the gap between 4MB and 250MB is massive but the accuracy gap
is 0.3%. That is a thesis finding worth a full paragraph.

**Pretrained weights source (baseline used in notebook):**
```
facenet-pytorch library
InceptionResnetV1 trained on VGGFace2 (3.3M images, 9k identities)
Input: 160×160 RGB face image
Output: 512-dim L2-normalised embedding
```

**MobileFaceNet option (mobile-first):**
Use a MobileFaceNet implementation with 112×112 input and 128‑dim output.
If you switch, update preprocessing, export input shape, and thresholds.

---

## The Two Face Sources — Different Problems

You are comparing two face images that come from completely
different sources. This is the central challenge of this component.

### Source 1 — Selfie

```
Captured by: mobile camera, front-facing
Resolution: high (1080p+ typically)
Lighting: variable but user-controlled
Compression: once (JPEG encoding for upload)
Face size: large relative to frame
Quality: generally good
```

### Source 2 — Document Photo

```
Captured by: ID card printing process years ago
Resolution: low (passport photo ~300×400px original)
Printed at: 300 DPI onto plastic card
Photographed by: your mobile camera rear lens
Compression: TWICE (printing + JPEG encoding)
Face size: small (roughly 80-120px after cropping from card)
Quality: variable — faded ink, scratches, glare on laminate
```

These two images are fundamentally different in quality.
Your model has to bridge that gap. No amount of training
fully eliminates it — you manage it with calibration.

---

## Full Pipeline

```
MOBILE (pre-screening only)
  ML Kit Face Detection
    → confirm face present in selfie before capture
    → get bounding box coordinates for selfie

SERVER (authoritative)
  Step 0: Identify document type from OCR output
  Step 0b: Crop to face region of interest (ROI)
  Step 1: Detect face within ROI
  Step 1b: Assess document face quality
  Step 1c: Handle degraded or missing photo gracefully
  Step 2: Align both faces (doc + selfie)
  Step 3: Preprocess to model input size (baseline: 160×160)
  Step 4: Run MobileFaceNet on both
  Step 5: Compute cosine similarity
  Step 6: Apply threshold → match / no match
  Step 7: Return face_similarity + quality flags
           to decision engine
```

---

## Step 0 — Region of Interest Crop (Do This First)

Before running any face detector on the document image,
crop to the region where the face is expected to be.

This matters because the full document image contains
logos, text blocks, barcodes, watermarks, and the Nigerian
coat of arms — all of which can confuse a general face
detector. Cropping to the face region first makes detection
faster and dramatically more reliable.

### NIN Card Face Region

```
Full warped document: 856 × 540 px

NIN smart card face location:
  Top-left area of the card
  Approximately left 35% horizontally
  Approximately 15%–80% vertically
```

```python
def get_face_roi(document_image, doc_type='nin_smart'):
    """
    Crop to expected face region before running detection.
    Ratios are approximate — adjust after testing on real cards.
    """
    h, w = document_image.shape[:2]

    regions = {
        'nin_smart': (0.03, 0.38, 0.15, 0.80),  # x1, x2, y1, y2
        'voter_card': (0.03, 0.35, 0.20, 0.75),
        'passport':   (0.25, 0.75, 0.10, 0.60),
        'unknown':    (0.00, 0.50, 0.00, 1.00),  # left half fallback
    }

    x1_r, x2_r, y1_r, y2_r = regions.get(doc_type, regions['unknown'])
    x1, x2 = int(w * x1_r), int(w * x2_r)
    y1, y2 = int(h * y1_r), int(h * y2_r)

    roi = document_image[y1:y2, x1:x2]

    # Store offset so we can map coordinates back to full image
    offset = (x1, y1)
    return roi, offset
```

### What If Document Type Is Unknown

```python
def detect_document_type(ocr_text):
    """
    Use OCR output to identify document type.
    Runs after OCR, before face ROI crop.
    """
    text_upper = ocr_text.upper()

    if 'NATIONAL IDENTITY' in text_upper or 'NIMC' in text_upper:
        return 'nin_smart'
    if 'VOTERS' in text_upper or 'INEC' in text_upper:
        return 'voter_card'
    if 'FEDERAL REPUBLIC OF NIGERIA' in text_upper \
       and 'PASSPORT' in text_upper:
        return 'passport'

    return 'unknown'  # fallback to left-half crop
```

---

## Step 1 — Face Detection on Document

### The Problem
The face on the ID card is small and surrounded by text,
borders, logos, and other visual elements. A general face
detector trained on portrait photos may struggle with
a tiny printed face in a complex document layout.

### Solution — Two-Stage Detection
```python
import cv2
from deepface import DeepFace  # or use InsightFace detector

def detect_document_face(document_image):
    """
    Detect face region on ID card document image.
    Returns cropped face or None if not found.
    """
    # Stage 1: Try RetinaFace (best for small faces)
    try:
        result = DeepFace.detectFace(
            document_image,
            detector_backend='retinaface',
            enforce_detection=True
        )
        return result  # returns aligned face (resize later)
    except:
        pass

    # Stage 2: Fall back to MTCNN
    try:
        result = DeepFace.detectFace(
            document_image,
            detector_backend='mtcnn',
            enforce_detection=True
        )
        return result
    except:
        pass

    # Stage 3: Fall back to OpenCV Haar cascade
    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    )
    gray = cv2.cvtColor(document_image, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 4)

    if len(faces) > 0:
        x, y, w, h = faces[0]
        return document_image[y:y+h, x:x+w]

    return None  # No face found — see degradation handling below

---

## Step 1b — Document Face Quality Check

Before attempting embedding, verify the detected face
crop is actually usable. Attempting to embed a 30×35px
faded face produces garbage embeddings that silently
corrupt your face_similarity score.

```python
def assess_document_face_quality(face_crop):
    """
    Returns quality assessment before embedding attempt.
    """
    if face_crop is None:
        return {
            'usable': False,
            'reason': 'NO_FACE_DETECTED',
            'quality_score': 0.0
        }

    h, w = face_crop.shape[:2]

    # Minimum size check
    # Below 40×40: upscaling introduces too much distortion
    if h < 40 or w < 40:
        return {
            'usable': False,
            'reason': 'FACE_TOO_SMALL',
            'quality_score': 0.1,
            'size_px': (w, h)
        }

    # Blur check — Laplacian variance
    # A sharp face image has high variance
    # A blurry or faded face has low variance
    gray = cv2.cvtColor(face_crop, cv2.COLOR_BGR2GRAY)
    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()

    if blur_score < 20:
        return {
            'usable': False,
            'reason': 'FACE_TOO_BLURRY',
            'quality_score': 0.2,
            'blur_score': blur_score
        }

    # Brightness check — very dark or overexposed
    mean_brightness = np.mean(gray)
    if mean_brightness < 30 or mean_brightness > 230:
        return {
            'usable': False,
            'reason': 'FACE_POOR_LIGHTING',
            'quality_score': 0.3,
            'brightness': mean_brightness
        }

    # Passed all checks
    quality_score = min(1.0, blur_score / 100.0)
    return {
        'usable': True,
        'reason': 'OK',
        'quality_score': round(quality_score, 3),
        'size_px': (w, h),
        'blur_score': blur_score
    }
```

---

## Step 1c — Degradation Handling (Missing or Unusable Photo)

This is what happens when the document face quality
check fails. Three distinct scenarios with different responses.

### Scenario A — Old NIMC Paper Slip (No Photo)

The old paper NIN slip has no photo. Still valid identity
document. Your system must not reject it outright.

```python
if quality['reason'] == 'NO_FACE_DETECTED':
    return {
        'face_similarity': None,
        'doc_face_available': False,
        'routing': 'MANUAL_REVIEW',
        'reason': 'Document has no photo — requires human verification'
    }
```

### Scenario B — Photo Exists But Too Degraded

Face found but quality below threshold.
Still attempt matching but flag it and reduce confidence.

```python
if not quality['usable'] and quality['reason'] != 'NO_FACE_DETECTED':
    # Attempt embedding anyway on best available crop
    # But apply confidence penalty in decision engine
    doc_embedding = embedder.embed(preprocess_face(face_crop))
    similarity = cosine_similarity(doc_embedding, selfie_embedding)

    return {
        'face_similarity': similarity,
        'doc_face_low_quality': True,
        'doc_face_quality_score': quality['quality_score'],
        'doc_face_reason': quality['reason'],
        # Decision engine will weight this lower
        'confidence_weight': 0.5
    }
```

### Scenario C — Face Found and Usable

Normal path — full confidence.

```python
if quality['usable']:
    doc_embedding = embedder.embed(preprocess_face(face_crop))
    similarity = cosine_similarity(doc_embedding, selfie_embedding)

    return {
        'face_similarity': similarity,
        'doc_face_available': True,
        'doc_face_low_quality': False,
        'doc_face_quality_score': quality['quality_score'],
        'confidence_weight': 1.0
    }
```

### Decision Engine Impact

```python
def compute_decision(signals):

    # Scenario A — no document photo at all
    if signals.get('face_similarity') is None:
        # Cannot verify identity automatically
        return 'MANUAL_REVIEW', 0.50

    # Scenario B — degraded photo
    face_weight = 0.15 if signals.get('doc_face_low_quality') else 0.35

    # Scenario C — normal
    # face_weight = 0.35 (full weight in scoring)
```

---
```

### Expected Face Region Size on Document
```
Full document image after warp: 856 × 540 px
NIN card face region: roughly top-left quadrant
Typical face crop before resize: 80–130 × 100–160 px
After resize to model input (baseline: 160×160): upscaled (quality loss here)
```

---

## Step 2 — Face Alignment

Alignment ensures both faces are in the same canonical
position — eyes at fixed coordinates, face centred.
Without alignment, two photos of the same person at
different angles produce artificially low similarity.

```python
def align_face(image, landmarks=None):
    """
    Align face using eye landmarks.
    MobileFaceNet was trained on aligned faces —
    alignment is not optional, it significantly
    affects embedding quality.
    """
    if landmarks is None:
        # Use deepface to detect landmarks
        analysis = DeepFace.analyze(image, actions=['landmarks'])
        landmarks = analysis['landmarks']

    left_eye = landmarks['left_eye']
    right_eye = landmarks['right_eye']

    # Calculate angle
    dY = right_eye[1] - left_eye[1]
    dX = right_eye[0] - left_eye[0]
    angle = np.degrees(np.arctan2(dY, dX))

    # Rotate to align eyes horizontally
    eye_center = (
        (left_eye[0] + right_eye[0]) // 2,
        (left_eye[1] + right_eye[1]) // 2
    )
    M = cv2.getRotationMatrix2D(eye_center, angle, 1.0)
    aligned = cv2.warpAffine(image, M, (image.shape[1], image.shape[0]))

    return aligned
```

### What Happens When Landmarks Fail on Document Photo
The printed face is small. Landmark detection (finding exact
eye positions) is harder on a tiny printed face.

**Fallback strategy:**
```python
try:
    aligned_doc_face = align_face(doc_face_crop)
except:
    # Use unaligned crop — lower accuracy but still works
    aligned_doc_face = cv2.resize(doc_face_crop, (160, 160))
    # Log this — it will show up as lower similarity scores
    alignment_failed = True
```

Track how often alignment fails in your evaluation.
If > 20% of document photos fail alignment — mention it
in limitations.

---

## Step 3 — Preprocessing

The embedding model expects a specific input format.
Getting this wrong produces garbage embeddings — the model
runs without error but similarity scores are random.

```python
def preprocess_face(image, target_size=(160, 160)):
    """
    Prepare face image for embedding model.
    Input: any size BGR image
    Output: (1, H, W, 3) float32 tensor, values in [-1, 1]
    """
    # Resize to model input size
    resized = cv2.resize(image, target_size,
                         interpolation=cv2.INTER_CUBIC)

    # Convert BGR to RGB (OpenCV loads BGR, model expects RGB)
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)

    # Normalise to [-1, 1]
    # This is the normalisation used by common face embedding models
    normalized = (rgb.astype(np.float32) - 127.5) / 128.0

    # Add batch dimension
    return np.expand_dims(normalized, axis=0)
```

⚠️ Common mistake: normalising to [0, 1] instead of [-1, 1].
The model will produce embeddings but similarity scores
will be systematically wrong. Always check the original
training normalisation.

---

## Step 4 — Running the Model (ONNX Runtime)

```python
import onnxruntime as ort
import numpy as np

class FaceEmbedder:
    def __init__(self, model_path='face_embedder.onnx'):
        self.session = ort.InferenceSession(
            model_path,
            providers=['CPUExecutionProvider']
        )
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name

    def embed(self, preprocessed_face):
        """
        preprocessed_face: (1, H, W, 3) float32 array
        returns: L2-normalised embedding (dim depends on model)
        """
        embedding = self.session.run(
            [self.output_name],
            {self.input_name: preprocessed_face}
        )[0]

        # L2 normalise (should already be normalised
        # but do it explicitly to be safe)
        embedding = embedding / np.linalg.norm(embedding)
        return embedding.flatten()
```

---

## Step 5 — Similarity Computation

```python
def cosine_similarity(embedding_a, embedding_b):
    """
    Both embeddings must be L2-normalised.
    If normalised: cosine_similarity = dot product.
    Returns value in [-1, 1], typically [0, 1] for faces.
    """
    return float(np.dot(embedding_a, embedding_b))

def face_similarity_score(doc_face_image, selfie_image, embedder):
    """
    Full pipeline: two images → similarity score
    """
    # Preprocess both
    doc_input = preprocess_face(doc_face_image)
    selfie_input = preprocess_face(selfie_image)

    # Get embeddings
    doc_embedding = embedder.embed(doc_input)
    selfie_embedding = embedder.embed(selfie_input)

    # Compute similarity
    similarity = cosine_similarity(doc_embedding, selfie_embedding)

    return {
        'face_similarity': similarity,
        'doc_alignment_ok': True,  # or False if alignment failed
        'doc_face_size_px': doc_face_image.shape[:2]
    }
```

---

## Step 6 — Threshold Calibration

This is where most tutorials go wrong. They use a single
fixed threshold derived from LFW. You have two different
scenarios that need different thresholds.

### LFW Threshold (clean photos)
```
Genuine pairs (same person): similarity typically 0.65–0.95
Impostor pairs (different): similarity typically 0.10–0.55
Decision threshold: ~0.60
EER at this threshold: target < 5%
```

### Document Photo Threshold (real-world)
```
Genuine pairs: similarity typically 0.40–0.80
  (lower because document photo is degraded)
Impostor pairs: similarity typically 0.05–0.45
Decision threshold: ~0.45
```

### How to Set the Right Threshold
```python
# During development — plot the distribution
import matplotlib.pyplot as plt

genuine_scores = []   # same person, doc vs selfie
impostor_scores = []  # different person, doc vs selfie

# Collect on your test samples
# Plot histogram to find natural separation point
plt.hist(genuine_scores, alpha=0.5, label='genuine', bins=20)
plt.hist(impostor_scores, alpha=0.5, label='impostor', bins=20)
plt.axvline(x=0.45, color='r', label='threshold')
plt.legend()
plt.savefig('threshold_calibration.png')

# Find EER threshold programmatically
from sklearn.metrics import roc_curve
fpr, tpr, thresholds = roc_curve(labels, scores)
fnr = 1 - tpr
eer_threshold = thresholds[np.argmin(np.abs(fnr - fpr))]
```

---

## LFW Evaluation Setup (No Training, Evaluation Only)

LFW (Labeled Faces in the Wild) is the standard benchmark
for face verification. This is how you get your EER number
for the thesis.

### Download and Setup
```python
# pip install deepface — includes LFW evaluation tools
# or download directly from:
# http://vis-www.cs.umass.edu/lfw/

# LFW comes with a standard pairs.txt file
# 3000 genuine pairs + 3000 impostor pairs
# This is the standard evaluation protocol
```

### Evaluation Code
```python
def evaluate_on_lfw(embedder, lfw_pairs_file, lfw_images_dir):
    """
    Standard LFW evaluation.
    Returns FAR, FRR, EER, AUC-ROC
    """
    pairs = load_lfw_pairs(lfw_pairs_file)
    labels = []
    scores = []

    for pair in pairs:
        img1 = load_and_preprocess(
            os.path.join(lfw_images_dir, pair['image1'])
        )
        img2 = load_and_preprocess(
            os.path.join(lfw_images_dir, pair['image2'])
        )

        emb1 = embedder.embed(img1)
        emb2 = embedder.embed(img2)

        similarity = cosine_similarity(emb1, emb2)
        scores.append(similarity)
        labels.append(1 if pair['same_person'] else 0)

    # Compute metrics
    fpr, tpr, thresholds = roc_curve(labels, scores)
    auc = auc_score(labels, scores)

    # EER — point where FAR == FRR
    fnr = 1 - tpr
    eer_idx = np.argmin(np.abs(fnr - fpr))
    eer = fpr[eer_idx]
    eer_threshold = thresholds[eer_idx]

    return {
        'eer': eer,                    # target < 0.05
        'eer_threshold': eer_threshold,
        'auc': auc,                    # target > 0.99
        'fpr': fpr,
        'tpr': tpr,
        'thresholds': thresholds
    }
```

### Expected Results on LFW

| Model | Expected EER | Your Target |
|---|---|---|
| InceptionResnetV1 FP32 | ~0.5% | Confirm this |
| MobileFaceNet FP32 | ~0.5–1.0% | Confirm this |
| INT8 PTQ | +1–3pp | Document delta |

The delta between FP32 and INT8 is your compression
study finding for this model. Face embedding is more
sensitive to quantisation than the quality classifier —
this is an expected and interesting thesis result.

---

## ONNX Export Pipeline

### From PyTorch to ONNX
```python
import torch
from facenet_pytorch import InceptionResnetV1

# Load pretrained MobileFaceNet
# Note: facenet-pytorch uses InceptionResnetV1 architecture
# For true MobileFaceNet use a dedicated repo
model = InceptionResnetV1(pretrained='vggface2').eval()

# Dummy input — must match model's expected input
dummy_input = torch.randn(1, 3, 160, 160)

# Export
torch.onnx.export(
    model,
    dummy_input,
    'face_embedder.onnx',
    export_params=True,
    opset_version=11,
    input_names=['input'],
    output_names=['output'],
    dynamic_axes={
        'input': {0: 'batch_size'},
        'output': {0: 'batch_size'}
    }
)
print("Exported successfully")
```

### Validate the Export
```python
import onnx
import onnxruntime as ort

# Check model is valid
model = onnx.load('face_embedder.onnx')
onnx.checker.check_model(model)
print("Model structure valid")

# Check inference produces same output as PyTorch
session = ort.InferenceSession('face_embedder.onnx')
test_input = np.random.randn(1, 3, 160, 160).astype(np.float32)

# PyTorch output
with torch.no_grad():
    pt_output = model(torch.tensor(test_input)).numpy()

# ONNX output
onnx_output = session.run(None, {'input': test_input})[0]

# Should be near identical
max_diff = np.max(np.abs(pt_output - onnx_output))
print(f"Max difference PyTorch vs ONNX: {max_diff}")
# Acceptable: < 1e-5
# If > 1e-3: something is wrong with the export
```

### INT8 Quantisation
```python
from onnxruntime.quantization import quantize_dynamic, QuantType

quantize_dynamic(
    'face_embedder.onnx',
    'face_embedder_int8.onnx',
    weight_type=QuantType.QInt8
)

# Measure size reduction
fp32_size = os.path.getsize('face_embedder.onnx') / (1024*1024)
int8_size = os.path.getsize('face_embedder_int8.onnx') / (1024*1024)
print(f"FP32: {fp32_size:.1f}MB  INT8: {int8_size:.1f}MB")
print(f"Reduction: {fp32_size/int8_size:.1f}x")
```

### Latency Benchmark (for thesis table)
```python
import time

def benchmark_inference(session, n_runs=100):
    test_input = np.random.randn(1, 3, 160, 160).astype(np.float32)
    input_name = session.get_inputs()[0].name

    # Warmup
    for _ in range(10):
        session.run(None, {input_name: test_input})

    # Benchmark
    times = []
    for _ in range(n_runs):
        start = time.perf_counter()
        session.run(None, {input_name: test_input})
        times.append((time.perf_counter() - start) * 1000)

    return {
        'mean_ms': np.mean(times),
        'p95_ms': np.percentile(times, 95),
        'min_ms': np.min(times)
    }

fp32_session = ort.InferenceSession('face_embedder.onnx')
int8_session = ort.InferenceSession('face_embedder_int8.onnx')

fp32_bench = benchmark_inference(fp32_session)
int8_bench = benchmark_inference(int8_session)
```

---

## Compression Study Results Table (Face Embedding)

Fill this in after running experiments:

| Variant | Size (MB) | LFW EER (%) | Latency mean (ms) | Latency p95 (ms) |
|---|---|---|---|---|
| FP32 (baseline) | TBD | TBD | TBD | TBD |
| INT8 PTQ | TBD | TBD | TBD | TBD |
| Distilled | TBD | TBD | TBD | TBD |

Expected finding: INT8 EER increase will be larger here
than for the quality classifier. This asymmetry between
classification models and embedding models under quantisation
is a publishable finding.

---

## Edge Cases

### Edge Case 1 — No Face Found on Document
```python
doc_face = detect_document_face(document_image)

if doc_face is None:
    return {
        'face_similarity': 0.0,
        'error': 'NO_FACE_ON_DOCUMENT',
        'decision': 'REJECT'
    }
```
Reason: document is folded, face region is obscured,
very old card with faded photo, or wrong document type
submitted (utility bill instead of ID).

### Edge Case 2 — Multiple Faces on Document
Some documents (family documents, letters with photos)
may have multiple faces. Take the largest face region
as it is most likely the document owner photo.

```python
faces = detect_all_faces(document_image)
if len(faces) > 1:
    # Take largest bounding box
    doc_face = max(faces, key=lambda f: f['w'] * f['h'])
```

### Edge Case 3 — Selfie Has Multiple Faces
User has someone else in the frame.

```python
selfie_faces = detect_all_faces(selfie_image)
if len(selfie_faces) > 1:
    return {
        'face_similarity': 0.0,
        'error': 'MULTIPLE_FACES_IN_SELFIE',
        'decision': 'REJECT'
    }
```

### Edge Case 4 — Face Too Small to Process
If the detected face region is smaller than 40×40 pixels
even before cropping, the document photo is too degraded
for reliable embedding.

```python
if doc_face.shape[0] < 40 or doc_face.shape[1] < 40:
    return {
        'face_similarity': None,
        'error': 'DOCUMENT_FACE_TOO_SMALL',
        'confidence_penalty': 0.3  # reduce ocr_confidence too
    }
```

### Edge Case 5 — Glasses, Mask, Occlusion
Handled by the liveness active challenge (blink + head turn
requires unoccluded face). But at the face embedding stage
you cannot fully correct for occlusion. If both document
photo and selfie have glasses this is less of a problem
(both embeddings are affected equally). The dangerous case
is document photo without glasses, selfie with glasses —
similarity will drop.

**For thesis:** Note this as a known limitation.
**Threshold adjustment:** Not recommended — better to ask
the user to remove glasses if similarity drops below threshold.

---

## What to Report in Thesis

### Section: Face Embedding Evaluation

```
1. LFW results table (baseline, INT8, optional MobileFaceNet)
   - EER per variant
   - Size per variant
   - Latency per variant

2. ROC curve figure
   - FP32 vs INT8 vs Distilled on same axes
   - Mark the EER operating point

3. Threshold calibration paragraph
   - LFW threshold vs document photo threshold
   - Explain why they differ (document photo degradation)
   - Report how you determined the document threshold

4. Failure analysis
   - How many document photos had no detectable face?
   - How many had alignment failure?
   - What is the similarity distribution for genuine pairs?
```

---

## Thesis Claims — What You Can and Cannot Say

**Can claim:**
- MobileFaceNet pretrained on VGGFace2 achieves EER [X]% on LFW
- INT8 quantisation increases EER by [X]pp — higher than
  the quality classifier ([X]pp), confirming embedding models
  are more sensitive to quantisation than classifiers
- Document photo degradation reduces similarity scores by
  approximately [X] points vs clean photo pairs
- Region of interest cropping improves face detection
  reliability on Nigerian ID documents vs full-image detection
- Graceful degradation strategy routes no-photo documents
  to manual review rather than automatic rejection —
  preserving accessibility for older document generations

**Cannot claim:**
- You trained a face recognition model (you did not)
- Your system handles all face types equally
  (demographic evaluation is future work)
- Document photo accuracy matches LFW accuracy
  (it will not — this is expected and documented)

**Limitations section:**
- Real document photo quality degrades face similarity vs LFW benchmark
- Old NIMC paper slips have no photo — automatic routing to manual review
- ROI coordinates are approximate — may need adjustment for
  document generations not seen during development
- Cross-document-type generalisation is future work

---

## Time Estimate

| Task | Time |
|---|---|
| Load pretrained weights + verify inference | 2 hours |
| ONNX export + validation | 2–3 hours |
| LFW evaluation script | Half day |
| INT8 quantisation + benchmark | 2 hours |
| ROI crop + document type detection | 2–3 hours |
| Document face detection + quality check | 1 day |
| Degradation handling (missing/faded photo) | 2–3 hours |
| Face alignment | Half day |
| Threshold calibration on real samples | Half day |
| Knowledge distillation variant | 2–3 days |
| **Total (without distillation)** | **3–4 days** |
| **Total (with distillation)** | **6–7 days** |

---

*Document created: March 2026*
*Part of: KYC AI Thesis — Master of Science, Embedded AI, ATBU Bauchi*
*Next: DOC_Liveness_Detection_Pipeline.md*
