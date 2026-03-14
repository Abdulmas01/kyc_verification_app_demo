# AI-Based Automated KYC Verification System
## Master of Science in Artificial Intelligence — Thesis Project Specification

---

## Research Overview

### Problem Statement

Know Your Customer (KYC) verification is a mandatory identity authentication process required by financial institutions, fintech platforms, and regulated services worldwide. Traditional KYC processes are manual, slow, and expensive. Automating KYC with AI introduces new challenges: the system must be accurate enough for real-world deployment, resistant to spoofing attacks, privacy-preserving, and efficient enough to run on consumer mobile devices.

This thesis investigates the design, training, and optimization of a **multi-model deep learning pipeline** that performs automated KYC verification entirely from mobile inputs. The central AI research questions are:

1. Can lightweight neural networks, optimized for mobile inference, match the accuracy of full-size models for document verification and biometric matching tasks?
2. What is the accuracy-efficiency tradeoff across quantization, pruning, and knowledge distillation for each biometric sub-task?
3. How robust are deep learning-based liveness detection models against spoofing attacks, including passive (texture-based) and active (challenge-response) signal fusion?
4. Can a probabilistic risk calibration model outperform a hand-engineered weighted scoring function for multi-signal identity decision making?

### Primary AI Contributions

This thesis makes the following original AI contributions:

1. **Mobile-optimized biometric pipeline** — a system of task-specialized lightweight neural networks covering document quality assessment, face embedding, and liveness detection, each trained, compressed, and benchmarked for mobile-CPU inference on mid-range Android devices.

2. **Synthetic identity document dataset** — a programmatically generated training corpus of 20,000–50,000 annotated identity documents with controlled augmentation, enabling supervised training without real personal data.

3. **Compression study: PTQ and knowledge distillation across biometric tasks** — a systematic empirical comparison of post-training INT8 quantization and knowledge distillation applied to each biometric model, producing concrete accuracy–latency–size tradeoff curves. Different biometric tasks exhibit fundamentally different sensitivity to quantization — this per-task analysis is the core empirical contribution.

4. **Passive liveness detection with active challenge-response fusion** — a MobileNetV2 classifier trained on OULU-NPU for texture-based anti-spoofing (print, screen, and video replay attacks), fused with active challenge-response (blink detection and head-turn tracking) via Google ML Kit Face Detection.

5. **Calibrated probabilistic decision engine** — a systematic comparison of a hand-engineered weighted scoring formula (baseline) against learned calibration models (logistic regression and XGBoost with isotonic calibration), evaluated using calibration-specific metrics (ECE, Brier score) that are standard in probabilistic ML but rarely applied to KYC decision engine literature.

### OCR Strategy

On-device OCR uses **Google ML Kit Text Recognition v2** — a free, production-grade, on-device library supporting Latin and Arabic scripts, requiring no training data. Server-side Tesseract OCR serves as fallback when on-device confidence falls below 0.65. The thesis contribution in this module is the field extraction logic, confidence scoring pipeline, and field validation rules built on top of ML Kit — not a custom OCR model. This mirrors the practice of production KYC systems and allows the research focus to remain on the novel biometric components.

---

## Document Structure

This specification is organized around the AI research work:

- **Section 1** — Threat Model (defines the AI problem constraints)
- **Section 2** — Synthetic Dataset Design (training data strategy)
- **Section 3** — Mobile Inference Architecture (deployment constraints)
- **Section 4** — AI Model Architectures (core contribution — detailed per module)
- **Section 5** — Model Training Methodology (loss functions, optimizers, training strategy)
- **Section 6** — Model Optimization Strategy (compression experiments)
- **Section 7** — Decision Engine & Risk Calibration (fusion model)
- **Section 8** — Evaluation & Benchmark Design
- **Section 9** — System Architecture & Data Flow
- **Section 10** — Critical Gaps & Alternative AI Approaches
- **Section 11** — Expected AI Contributions & Limitations
- **Section 12** — Experiment Plan & Tables

---

# 1. Threat Model & Attack Scenarios

A KYC system is a high‑risk security system. Attackers will attempt to bypass identity verification through multiple spoofing and manipulation strategies.

The threat model defines:

• Who the attackers are
• What they are trying to achieve
• How they may attack the system
• What defenses the system must implement

---

## 1.1 Attacker Goals

Typical attacker objectives:

1. **Impersonation**

Use another person's identity to pass verification.

2. **Synthetic Identity Creation**

Create fake identity documents that appear valid.

3. **Account Takeover**

Use stolen documents and attempt to pass biometric verification.

4. **Automation Attacks**

Use bots to repeatedly attempt verification until successful.

---

## 1.2 Attack Surface

The system has several entry points where attacks can occur.

### Document Capture Stage

Possible attacks:

• Uploading **edited documents**
• Uploading **screenshots of documents**
• Uploading **low‑quality blurred documents** to confuse OCR

Mitigations:

• Image quality scoring
• Document boundary detection
• Perspective correction
• Glare and blur detection

---

### OCR Manipulation

Attackers may attempt:

• Text overlay on ID images
• Fake document layouts
• Altered ID numbers

**Mitigations implemented in this thesis:**

• Field format validation — NIN must match 11-digit numeric
  pattern with no leading zero. OCR character substitution
  errors (O→0, I→1) corrected before validation.

• Cross-field consistency checks — date of birth implies
  age ≥ 18, expiry date must be after issue date, date
  logic impossibilities (issue after expiry) flagged
  automatically.

• OCR confidence scoring — ML Kit per-block confidence
  aggregated into a single `field_valid_score` signal
  that feeds the decision engine. Consistently low
  confidence across a document flags it for manual review.

**Out of scope — designated future work:**

• Layout consistency checks — reliable layout verification
  requires a trained document layout model or geometric
  template matching system evaluated against a labelled
  dataset of genuine vs fake documents. Neither is feasible
  within the thesis timeline and neither is claimed as
  a contribution here.

• Image manipulation detection — detecting text overlays
  or Photoshop alterations requires a trained forensics
  model. This is an active research area beyond the scope
  of this thesis.

**Honest scope statement:**

The OCR security layer addresses opportunistic document
fraud — lazy attacks using incorrect formats or internally
inconsistent fields. Sophisticated document forgery is
addressed by the face matching layer (wrong person presents
genuine document) and the liveness layer (non-live
presentation). No OCR-based system operating without
database verification against government records can fully
solve document authenticity. This is a known limitation
of all offline mobile KYC systems and is explicitly
acknowledged rather than obscured.

---

### Face Verification Attacks

Attackers may try to match the ID photo with a fake face.

Common attacks:

• Printed face photos
• Face displayed on another phone screen
• AI generated faces

Mitigations:

• Face embedding similarity thresholds
• Liveness detection
• Multi‑frame capture

---

### Liveness Spoofing Attacks

Examples:

1. Printed photo
2. Screen replay
3. Video replay
4. Deepfake video

Mitigation techniques:

• Texture analysis
• Reflection detection
• Micro‑movement detection
• Blink detection
• Head motion challenge

---

## 1.3 Risk Scoring Strategy

Instead of binary decisions, the system computes a **risk score**.

Inputs:

• Document quality score
• OCR confidence
• Face similarity
• Liveness probability

Example scoring:

Risk Score = weighted combination of signals

Decision thresholds:

Accept → risk < 0.3

Manual Review → 0.3 ≤ risk ≤ 0.6

Reject → risk > 0.6

---

## 1.4 System Abuse Protection

Additional safeguards:

**Rate limiting**
Maximum 5 verification attempts per user per day.

**Device fingerprinting**
Detect repeated attempts from same device.

**IP anomaly detection**
Flag high‑risk locations.

**Idempotency Key / Hash Check**
Prevent replay attacks by tracking hashes of recently submitted payloads to ensure duplicate or intercepted responses cannot be reused.

**Spoof Threshold Penalty**
Progressively penalize or lock out users/devices that repeatedly hit high spoof probabilities, deterring brute-force presentation attacks.

---

# 2. Synthetic Dataset Generator Design

One of the biggest challenges of this project is **dataset availability**.

Real KYC datasets cannot easily be obtained due to:

• Privacy laws
• Financial regulations
• Personal identity exposure

Therefore the project introduces a **Synthetic Dataset Generator**.

---

## 2.1 Goals of Synthetic Dataset Generator

The generator must produce realistic ID documents that can train:

• OCR systems
• Document detection
• Layout extraction

The generated dataset must include:

• Different document layouts
• Randomized identity data
• Realistic image distortions

---

## 2.2 Synthetic Document Generation Pipeline

Pipeline steps:

1. Template Selection

Example templates:

• Driver license
• National ID
• Passport

Each template defines:

• Field positions
• Font styles
• Document layout

---

2. Identity Data Generation

Random fields:

• Name
• Date of birth
• ID number
• Expiry date

Data sources:

• Faker library
• Random number generators

---

3. Face Image Injection

Face images may come from:

• Public face datasets
• Generated faces

The system inserts a face image into the ID template.

---

4. Rendering Engine

The final ID card is rendered as an image.

Libraries:

Python PIL

OpenCV

---

5. Augmentation Engine

To simulate real-world camera conditions the system applies:

Blur

Gaussian noise

Lighting variation

Perspective distortion

Glare simulation

Compression artifacts

---

## 2.3 Dataset Diversity Strategy

The generator should produce variations such as:

Different fonts

Different background colors

Different ID layouts

Different image noise levels

Goal:

Ensure the OCR system generalizes to unseen documents.

---

## 2.4 Label Generation

Every generated document includes ground truth labels.

Example labels:

{

name: "John Smith",

id_number: "ID9348201",

dob: "1992-04-17",

bbox_name: [x1,y1,x2,y2]

}

This enables supervised training.

---

## 2.5 Dataset Size Targets

For research quality training:

Document dataset target:

20,000 – 50,000 synthetic IDs

Augmented dataset:

200,000+ samples after augmentation

---

# 3. Pipeline Architecture — Server-Authoritative Hybrid

This section defines the KYC pipeline architecture. The system uses a
**server-authoritative hybrid** design: mobile handles real-time UX feedback
and capture guidance, server handles all authoritative biometric inference
that feeds the final decision.

This design was chosen after evaluating a fully edge-first alternative. The
edge-first architecture — where all biometric scores are generated on-device
and transmitted to the server — introduces a payload tampering vulnerability
(documented in Section 9.0.4) that cannot be fully mitigated without moving
authoritative inference to the server. The hybrid design eliminates this
vulnerability entirely while preserving the UX benefits of on-device
pre-screening.

---

## 3.1 Responsibility Split

### Mobile Device — Pre-screening and UX only

The mobile device is responsible for guiding the user to a good capture and
running active liveness challenges. It does not produce any score that feeds
the final decision.

| Task | Technology | Purpose |
|---|---|---|
| Document quality scoring | TFLite (doc_quality model) | Real-time camera guidance — "Hold steady", "Move to better light" |
| Document boundary detection | ML Kit Object Detection | Frame the document correctly |
| Face detection | ML Kit Face Detection | Ensure face is present before capture |
| Active liveness challenges | ML Kit Face Detection | Blink + head-turn challenge-response |
| Image encryption | AES-256-GCM | Secure image before upload |
| Payload signing | ECDSA (Android Keystore TEE) | Attest payload integrity |
| Play Integrity attestation | Google Play Integrity API | Attest device and app authenticity |

**Key principle:** The document quality score from the mobile device is used
only for camera UX feedback. It is not sent to the server and does not feed
the decision engine. The server computes its own authoritative quality
assessment from the uploaded image.

### Server — All authoritative inference

The server receives encrypted images and computes all scores that feed the
decision engine. No client-generated biometric scores are trusted for the
final decision.

| Task | Technology | Input | Output |
|---|---|---|---|
| Document quality (authoritative) | ONNX Runtime — quality model | Document image | quality_score |
| OCR + field extraction | ML Kit (primary) / Tesseract (fallback) | Document image | extracted_fields, ocr_confidence |
| Face embedding extraction | ONNX Runtime — face model | Selfie frame | 128-dim embedding |
| Face similarity | Cosine similarity | Doc face + selfie embedding | face_similarity |
| Passive liveness scoring | ONNX Runtime — liveness model | Selfie frame | liveness_score |
| Play Integrity verification | Google Play Integrity API | Integrity token | device_ok, app_ok |
| Payload signature verification | ECDSA-P256 | Signed payload | signature_valid |
| Decision engine | XGBoost + logistic regression | All scores | P(genuine) → decision |
| Audit logging | PostgreSQL | Full session | Immutable record |

---

## 3.2 End-to-End Flow

### Phase 1 — Session Initialisation

```
App calls POST /api/v1/verify/start/
  → Server creates session, returns session_token + upload_nonce
  → App stores session_token for all subsequent calls
```

### Phase 2 — Document Capture (Mobile)

```
1. Live camera stream starts
2. Every 3rd frame → doc_quality TFLite model (on-device)
   → GOOD: green overlay, "Hold steady"
   → BLURRY: "Hold the phone still"
   → GLARE: "Move away from the light source"
   → DARK: "Move to a brighter area"
   → NO_DOCUMENT: "Centre your ID card in the frame"
3. Quality GOOD sustained for 1.5 seconds → auto-capture
4. ML Kit detects document boundary → perspective warp → normalised image
5. Image encrypted with AES-256-GCM using session key
```

### Phase 3 — Selfie + Liveness Capture (Mobile)

```
1. Face detection overlay appears
2. ML Kit Face Detection runs active challenges:
   → "Blink" — detects eye closure (EAR threshold)
   → "Turn left" — detects head euler Y rotation
   → "Turn right" — detects head euler Y rotation
3. All three challenges completed → auto-capture selfie frame
4. Challenge result (boolean) + ML Kit confidence scores recorded
5. Selfie frame encrypted with AES-256-GCM
```

### Phase 4 — Secure Upload (Mobile → Server)

```
App calls POST /api/v1/verify/upload/
  Payload:
  {
    session_token: "sess_abc...",
    document_image: <AES-256-GCM encrypted, base64>,
    selfie_image:   <AES-256-GCM encrypted, base64>,
    challenge_result: {
      blink_completed: true,
      head_left_completed: true,
      head_right_completed: true,
      mlkit_face_confidence: 0.97
    },
    integrity_token: <Play Integrity token>,
    payload_signature: <ECDSA signature of payload hash>,
    app_version: "1.0.0",
    model_version: "v1.2.0"
  }

Server immediately:
  1. Verifies Play Integrity token with Google
  2. Verifies ECDSA payload signature
  3. Decrypts images using session key
  4. Queues Celery task for inference pipeline
  5. Returns HTTP 202 Accepted + estimated_wait_ms
```

### Phase 5 — Server Inference Pipeline (Celery task)

```
Runs asynchronously — typically 1.5–3 seconds total:

1. Document quality (ONNX) → quality_score
2. ML Kit OCR → extracted_fields, ocr_confidence
   If ocr_confidence < 0.65 → Tesseract fallback
3. Field validation → field_valid_score
4. Face detection on document image → document_face_crop
5. Face detection on selfie → selfie_face_crop
6. Face embedding (ONNX) on both crops → embed_doc, embed_selfie
7. Cosine similarity(embed_doc, embed_selfie) → face_similarity
8. Passive liveness (ONNX) on selfie → liveness_score
9. Fuse: liveness_score × challenge_weight → combined_liveness
10. Decision engine:
    Input: [face_similarity, combined_liveness, ocr_confidence,
            quality_score, field_valid_score]
    Output: P(genuine) → ACCEPT / MANUAL_REVIEW / REJECT
11. Write immutable audit record
12. POST result to business webhook
```

### Phase 6 — Result Delivery

```
App polls GET /api/v1/verify/{session_id}/
  or receives push notification when webhook fires

Response:
{
  decision: "ACCEPT",
  risk_score: 0.07,
  reason_codes: [],
  session_id: "uuid",
  reference: "business-user-id"
}
```

---

## 3.3 Why This Architecture Is Correct

**Security:** All scores that feed the decision engine are computed on the
server from the raw image. There are no client-generated biometric scores to
fabricate. Payload signing and Play Integrity attest that the images came from
a genuine unmodified app — they do not need to attest score values because
there are no client score values to attest.

**Privacy:** Images are encrypted on-device before upload. The server decrypts
only for inference and deletes the raw image after the session completes
(configurable retention policy). The mobile TFLite quality model still means
most poor-quality attempts are caught before any image is uploaded — reducing
unnecessary biometric data transmission.

**UX:** The on-device quality model gives the user instant camera feedback
(10–30ms per frame) while the upload is only triggered once quality is
confirmed. Total end-to-end time is 3–6 seconds — competitive with
fully on-device pipelines.

**Cost:** ONNX Runtime inference on CPU for these model sizes costs
approximately $0.03–0.06 per verification in server compute. This is
acceptable at the Verydent pricing tiers and still 5–20× cheaper than
Jumio/Onfido server costs due to the compressed model sizes from the
compression study.

---

## 3.4 Performance Targets

| Step | Where | Target latency |
|---|---|---|
| Quality scoring per frame | Mobile | 10–30ms |
| ML Kit face detection | Mobile | 15–40ms |
| Active challenge completion | Mobile | 3–8 seconds (user action) |
| Image encryption + upload | Mobile → Server | 500ms–1.5s (network dependent) |
| Server inference pipeline | Server (Celery) | 1.5–3s |
| Total end-to-end (good network) | — | 3–6 seconds |
| Total end-to-end (2G / slow network) | — | 6–15 seconds |

**Comparison to edge-first:** A fully on-device pipeline achieves 2–4 seconds
on a mid-range Android device. The server-authoritative hybrid adds 1–3 seconds
for network upload. This is the security cost of the architecture — explicitly
accepted as the right tradeoff for a production KYC system.

End-to-end target:

- Under 5 seconds total user time (including capture UX)

---

## 3.4 Mobile Model Packaging

Recommended packaging approach:

- Export models to **TFLite** (Android) and/or **ONNX Runtime Mobile**
- Use int8 quantization for CPU inference
- Keep models modular:

- doc_quality.tflite
- doc_detector.tflite
- face_embedder.tflite
- liveness.tflite

Benefits:

- Easy A/B testing of individual modules
- Independent optimization

---

## 3.5 Failure Handling (Engineering-Grade)

Define explicit failure states:

- QUALITY_FAIL (blur/glare/lighting)
- DOC_NOT_FOUND
- OCR_LOW_CONFIDENCE
- FACE_NOT_FOUND (selfie)
- FACE_NOT_FOUND (document)
- FACE_MISMATCH
- LIVENESS_FAIL

Each failure state maps to:

- User-facing guidance message
- Logged technical reason (for evaluation)

---

# 4. AI Model Architectures — Design & Justification

This section defines the neural network architecture for each AI module in the pipeline. Each model is chosen based on a balance of: accuracy on the target task, model size suitable for mobile deployment, and availability of pretrained weights for transfer learning.

The guiding principle is **task-specialized models** over a single general model — each sub-problem (quality, detection, OCR, face, liveness) has different input types, output types, and accuracy-efficiency tradeoffs.

---

## 4.1 Module 1 — Document Quality Classifier

### Task Definition

Binary or multi-class classification: given a camera frame, predict whether the document image quality is sufficient for downstream processing.

Output classes:
- `GOOD` — proceed to capture
- `BLURRY` — motion blur detected
- `GLARE` — specular reflection detected
- `DARK` — insufficient lighting
- `NO_DOCUMENT` — document not in frame

### Architecture

Base architecture: **MobileNetV3-Small**

Justification:
- Designed explicitly for mobile CPU inference
- Depthwise separable convolutions reduce FLOPs vs. standard convolutions by ~8–9×
- Hard-swish activation and squeeze-excitation blocks give better accuracy per parameter than MobileNetV2
- Pretrained on ImageNet — strong low-level feature extractor for transfer learning

Modification for this task:
- Replace final classification head with a 5-class softmax layer
- Add a lightweight attention module at the penultimate feature map to focus on texture regions (blur/glare are local artifacts)
- Input resolution: 224×224 (quality assessment benefits from full-resolution context)

Training strategy:
- Transfer learning: freeze early layers, fine-tune last 2 blocks + classification head
- Dataset: synthetic augmented document images with controlled quality labels

### Why Not a Larger Model?

Quality scoring runs on every live camera frame (real-time loop). Even at 30ms latency per frame, running at 30fps would consume 90% of CPU. MobileNetV3-Small inference targets 10–20ms on mid-range Android CPU.

---

## 4.2 Module 2 — Document Boundary Detector

### Task Definition

Localize the identity document within the camera frame and output its four corner coordinates (quadrilateral bounding box), enabling perspective correction.

Output: 8 floating-point values `[x1,y1, x2,y2, x3,y3, x4,y4]` — four corner points

### Architecture

Base architecture: **MobileNetV2 + lightweight Feature Pyramid Network (FPN) head**

Justification:
- MobileNetV2 inverted residual blocks provide efficient multi-scale feature extraction
- FPN aggregates features from multiple backbone stages — important for detecting documents at varying distances and scales
- This is a regression task (corner point coordinates), not classification — FPN head is replaced with a coordinate regression head

Alternative considered: **YOLO-family single-stage detector**

A YOLOv8-nano model is a strong alternative — it is designed for fast single-stage detection and has official TFLite export support. The tradeoff is that YOLO outputs axis-aligned bounding boxes by default; quadrilateral corner output requires architectural modification.

Recommended experiment: compare MobileNet+FPN corner regression vs. YOLOv8-nano detection accuracy and latency on document localization.

### Document Corner Regression Head

```
FPN feature map (7×7) → GlobalAveragePool → FC(256) → ReLU → FC(8) → corner coordinates
```

Loss function: Smooth L1 Loss on normalized corner coordinates

Post-processing: perspective transform using OpenCV `getPerspectiveTransform`

---

## 4.3 Module 3 — OCR Pipeline

### Task Definition

Extract structured text fields from a normalized identity document image.

Target fields:
- Full name
- Date of birth
- Document number / ID number
- Expiry date
- Nationality (where present)

### Primary Approach — Google ML Kit Text Recognition v2 (On-Device)

The OCR component uses **Google ML Kit Text Recognition v2** as the primary on-device text recognition engine.

Justification:
- Trained by Google on billions of real-world document images — far exceeds what any synthetic training dataset can provide
- On-device inference with no data transmission — aligns with the privacy-first architecture principle
- Supports Latin, Arabic, Chinese, Devanagari, Japanese, and Korean scripts
- Free with no per-call cost — direct startup cost advantage over cloud OCR APIs
- Already the standard choice in production mobile KYC systems

The thesis contribution in this module is **not** a custom OCR model. It is:
1. The field extraction pipeline that parses ML Kit raw text output into structured fields (name, ID number, DOB, expiry)
2. The confidence scoring system that estimates extraction reliability
3. The field validation rules that verify extracted values against known patterns (ID number formats, date ranges, name structure)
4. The fallback routing decision: when on-device confidence < 0.65, route to server-side Tesseract

### Fallback — Server-Side Tesseract OCR

When on-device ML Kit confidence falls below 0.65 (low lighting, damaged document, unusual font), the normalized document image is sent to the server where Tesseract OCR processes it.

Tesseract is used rather than a cloud OCR API (Google Vision, AWS Textract) to:
- Maintain cost control (Tesseract is open source)
- Avoid dependency on paid external services
- Keep the privacy boundary clear (image goes to your own server, not a third party)

### OCR Evaluation

OCR performance is measured on held-out synthetic documents with ground truth labels:

| Metric | Measurement |
|--------|-------------|
| Character Error Rate (CER) | Edit distance between predicted and ground truth text |
| Field accuracy — name | % of name fields correctly extracted |
| Field accuracy — ID number | % of ID numbers correctly extracted |
| Field accuracy — DOB | % of dates of birth correctly extracted |
| Confidence calibration | Correlation between confidence score and actual accuracy |

Comparison: on-device ML Kit vs. server Tesseract fallback on the same test set.

---

## 4.4 Module 4 — Face Embedding Model

### Task Definition

Given a face image (from selfie or extracted from document), produce a compact embedding vector such that:
- Same-person faces have high cosine similarity (> threshold)
- Different-person faces have low cosine similarity (< threshold)

### Architecture

Base architecture: **MobileFaceNet** (or ArcFace with MobileNetV2 backbone)

Justification:
- MobileFaceNet is specifically designed for face recognition on mobile devices
- 1MB model size, ~1ms inference on modern mobile hardware
- Achieves 99.55% accuracy on LFW with a model 20× smaller than ResNet-based ArcFace

Architecture details:
```
Input: 112×112×3 aligned face image
→ Conv 3×3 (64 filters)
→ Depthwise separable conv blocks × 4
→ Linear bottleneck layers
→ Global depthwise conv
→ FC → 128-dim embedding (L2 normalized)
```

The key design choice: **linear activation in the final bottleneck** (no ReLU) — preserves embedding discriminability.

### Loss Function — ArcFace Loss

Standard cross-entropy loss is insufficient for face embedding learning. **ArcFace (Additive Angular Margin Loss)** is used:

```
L = -log( e^(s·cos(θ_yi + m)) / (e^(s·cos(θ_yi + m)) + Σ_j≠yi e^(s·cos(θ_j))) )
```

Where:
- `θ_yi` = angle between embedding and class centre
- `m` = angular margin (typically 0.5 radians)
- `s` = feature scale (typically 64)

ArcFace forces the model to learn embeddings with clear angular separation between identities — significantly better than softmax loss for open-set verification (seen vs. unseen identities).

### Verification Threshold Tuning

After training, a threshold is selected on a held-out verification set:

- Compute cosine similarity for all genuine pairs (same person)
- Compute cosine similarity for all impostor pairs (different people)
- Plot FAR vs. FRR across thresholds
- Select EER (Equal Error Rate) point or application-appropriate operating point

---

## 4.5 Module 5 — Liveness Detection Model

### Task Definition

Given a selfie frame (128×128×3), classify whether the subject is:
- `LIVE` — a real live person in front of the camera
- `SPOOF` — a printed photo, screen display, or video replay

This is a **binary classification** problem with domain shift challenges (spoof types vary widely across attack categories).

### Architecture — Passive CNN with Active Challenge-Response Fusion

The liveness system combines two complementary components:

**Component 1 — Passive Texture CNN (trained model)**

Architecture: **MobileNetV2 fine-tuned as binary classifier on single frames**

```
Input: single frame (128×128×3)
→ MobileNetV2 feature extractor (pretrained ImageNet, fine-tuned)
→ Global Average Pool
→ FC(128) → ReLU → Dropout(0.3) → FC(2) → softmax
```

This model detects texture-level spoofing cues:
- Moiré patterns from screen replay attacks
- Paper grain texture from print attacks
- Specular reflection inconsistencies (flat on paper vs. curved on face)
- Skin micro-texture absent in reproduced images

Output: `liveness_score` — probability of LIVE class (0 to 1)

**Component 2 — Active Challenge-Response (Google ML Kit, no training required)**

Using **Google ML Kit Face Detection** with classification enabled, the Flutter app issues liveness challenges:
- Blink detection: `leftEyeOpenProbability` and `rightEyeOpenProbability` < 0.2 triggers blink confirmed
- Head turn left: `headEulerAngleY` < -20 degrees
- Head turn right: `headEulerAngleY` > +20 degrees

Challenge success is recorded as `challenge_success` boolean — a hard signal fed directly to the decision engine. A failed challenge triggers hard rejection regardless of the passive CNN score.

**Why this design over a temporal two-branch hybrid:**
A (2+1)D temporal CNN branch (factorised spatial + temporal convolutions over video sequences) was evaluated during the design phase. It was not adopted because:
- Implementation complexity is significantly higher than the accuracy gain justifies
- Training on video sequences requires substantially more GPU time and complex data loading
- Accuracy improvement on OULU-NPU is marginal (3–8% ACER) relative to the passive CNN baseline
- Active challenge-response via ML Kit provides equivalent temporal discrimination without a second model

### Loss Function

Weighted binary cross-entropy to handle class imbalance:

```
L = -[w_live · y · log(p) + w_spoof · (1-y) · log(1-p)]
```

Where `w_live` and `w_spoof` are set based on class frequency in the training split.

### Training Dataset

**Primary training dataset: CelebA-Spoof**

- 625,537 images across 10 spoof attack types (print, replay, partial, 3D mask, and more)
- Rich annotations including spoof type, illumination, environment, and sensor metadata
- License: Creative Commons Attribution 4.0 (CC BY 4.0) — permits commercial use with attribution
- Immediate download via GitHub release — no institutional access application required
- Larger and more attack-type-diverse than OULU-NPU; well-suited for MobileNetV2 fine-tuning

**Primary evaluation benchmark: CASIA-FASD**

- 600 video clips, 3 attack types (printed photo, video replay, cut photo)
- Widely cited in the anti-spoofing literature — ACER on CASIA-FASD is directly comparable to published results
- Free registration download — no waiting period
- Used for test set evaluation only (not training), ensuring clean train/test separation

**Secondary evaluation benchmark: OULU-NPU (conditional)**

- 4 attack protocols covering print and video replay under varied mobile capture conditions
- Gold standard for mobile liveness benchmarking — enables direct comparison with the widest range of published work
- Access requires a formal application to the University of Oulu (processing time 1–3 weeks)
- OULU-NPU access has been formally requested. If access is received before thesis submission, evaluation results on OULU-NPU Protocol 1 and Protocol 2 are included as a supplementary benchmark. If access is not received, CASIA-FASD results constitute the primary evaluation and OULU-NPU is noted as future work.

**Dataset licensing note for commercial continuity**

CelebA-Spoof (CC BY 4.0) is the only training dataset in this project with an explicit commercial use licence. Model weights trained exclusively on CelebA-Spoof are commercially deployable. Model weights trained on OULU-NPU or CASIA-FASD are for academic evaluation only. The production-deployable checkpoint is trained on CelebA-Spoof only; CASIA-FASD and OULU-NPU are used for evaluation and comparison, not training data augmentation.

### Liveness Evaluation Metrics

Per ISO/IEC 30107-3 standard:
- **APCER** — Attack Presentation Classification Error Rate: fraction of spoof attacks classified as live
- **BPCER** — Bona Fide Presentation Classification Error Rate: fraction of genuine users classified as spoof
- **ACER** = (APCER + BPCER) / 2 — primary headline metric
- ROC curve across classification thresholds

Expected result on OULU-NPU Protocol 1: ACER 5–12% with MobileNetV2 fine-tuning.

---

## 4.6 Summary — Model Selection Table

| Module | Architecture | Task Type | Input | Output | Size Target |
|--------|-------------|-----------|-------|--------|-------------|
| Doc Quality | MobileNetV3-Small | Multi-class classification | 224×224 | 5-class label | < 5MB |
| Doc Detector | MobileNetV2 + FPN | Corner regression | 320×320 | 8 coordinates | < 8MB |
| OCR | ML Kit (on-device) + Tesseract (server fallback) | Text recognition | Normalized doc | Structured fields | No custom model |
| Face Embedding | MobileFaceNet (pretrained VGGFace2) | Metric learning | 112×112 | 128-dim vector | < 2MB |
| Liveness | MobileNetV2 passive CNN + ML Kit active | Binary classification | 128×128 | Probability | < 10MB |

---

# 5. Model Training Methodology

This section defines how each AI model is trained — the datasets used, loss functions, optimization strategy, and regularization approach. This is a core academic contribution of the thesis and should be reproducible.

---

## 5.1 Training Framework

All models are trained using **PyTorch** with the following standard setup:

- Optimizer: **AdamW** (Adam with decoupled weight decay)
- Learning rate schedule: **Cosine Annealing with Warm Restarts**
- Mixed precision training: **FP16 AMP** (PyTorch `torch.cuda.amp`)
- Gradient clipping: max norm 1.0

Justification for AdamW over SGD:
- Decoupled weight decay improves generalization for transfer learning scenarios
- Faster convergence than SGD for fine-tuning pretrained models
- Better performance on small-to-medium datasets (which this project uses)

---

## 5.2 Transfer Learning Strategy

All models start from pretrained weights — no model is trained from scratch:

| Module | Pretrained Source | Fine-tune Strategy |
|--------|------------------|--------------------|
| Doc Quality (MobileNetV3-Small) | ImageNet-1K (timm) | Freeze early blocks, fine-tune last 2 + head |
| Doc Detector (MobileNetV2 + FPN) | COCO object detection | Fine-tune FPN + regression head |
| MobileFaceNet | VGGFace2 (facenet-pytorch) | Use directly, fine-tune head if needed |
| Liveness (MobileNetV2) | ImageNet-1K (timm) | Full fine-tune at low LR on OULU-NPU |

**Note on face embedding:** The pretrained VGGFace2 weights from `facenet-pytorch` are used directly. Training a face embedding model from scratch requires millions of face images with identity labels and weeks of GPU time — well beyond the scope of this thesis. Using pretrained weights is standard academic practice for this task.

Transfer learning protocol:
1. **Freeze all layers** — evaluate pretrained performance on target dataset
2. **Fine-tune last N blocks** — gradual unfreezing from head to backbone
3. **Full fine-tune** — low learning rate (1e-5 to 1e-4) on entire model

---

## 5.3 Data Augmentation Strategy (Per Module)

Augmentation is a critical regularization strategy, especially given the limited size of real-world training data.

### Document Quality / Detection Augmentation

```python
transforms = [
    RandomPerspective(distortion_scale=0.3),   # simulate camera angle
    RandomRotation(degrees=15),                 # document tilt
    ColorJitter(brightness=0.4, contrast=0.3),  # lighting variation
    GaussianBlur(kernel_size=(3,7)),            # focus blur
    RandomErasing(p=0.2),                       # occlusion simulation
    AddGaussianNoise(std=0.05),                 # sensor noise
]
```

### Face Embedding Augmentation

```python
transforms = [
    RandomHorizontalFlip(),
    ColorJitter(brightness=0.3, saturation=0.2),
    RandomGrayscale(p=0.05),
    RandomErasing(p=0.1, scale=(0.02, 0.1)),  # occlusion
    Normalize(mean=[0.5,0.5,0.5], std=[0.5,0.5,0.5])
]
```

### Liveness Detection Augmentation

Frame-level augmentation applied to OULU-NPU frames:
- Random brightness and contrast jitter (simulate lighting variation)
- Horizontal flip (mirror face)
- Gaussian noise (sensor noise simulation)
- Random crop and resize (simulate varying face sizes in frame)

---

## 5.4 Loss Functions Summary

| Module | Loss Function | Justification |
|--------|--------------|---------------|
| Doc Quality | Cross-Entropy + Label Smoothing (ε=0.1) | Standard multi-class, smoothing reduces overconfidence |
| Doc Detector | Smooth L1 (Huber) | Robust to corner localization outliers |
| OCR | ML Kit / Tesseract — no training loss | No custom OCR model |
| Face Embedding | ArcFace (Angular Margin, m=0.5, s=64) | Maximizes inter-class angular separation for open-set verification |
| Liveness | Weighted Binary Cross-Entropy | Handles class imbalance between genuine and spoof samples |
| Decision Engine | Log Loss (Logistic Regression) / XGBoost objective | Probabilistic calibration of multi-signal fusion |

---

## 5.5 Overfitting Prevention

Given the relatively small real-world dataset sizes, overfitting is a real risk. Strategies:

- **Dropout** (p=0.3) in classification heads
- **Label smoothing** (ε=0.1) for document quality and liveness classifiers
- **Early stopping** based on validation loss (patience=10 epochs)
- **Weight decay** (λ=1e-4) via AdamW
- **Data augmentation** as described in 5.3

---

## 5.6 Evaluation During Training

Each model logs the following metrics per epoch on the validation set:

- Document Quality: Accuracy, F1-score per class, Confusion matrix
- Document Detector: IoU (Intersection over Union) of predicted vs. ground truth corners
- OCR: Character Error Rate (CER), Field-level accuracy
- Face Embedding: AUC on LFW pairs, EER
- Liveness: APCER, BPCER, ACER, ROC-AUC

---

# 6. Model Optimization Strategy (Mobile Edge Constraints)

This section is a **core AI research contribution** of the thesis. Model compression for edge deployment is an active research area in deep learning. The thesis conducts a systematic empirical study of two compression techniques applied to three biometric models: document quality classifier, face embedding model, and liveness detection model.

**Central research question:** *What is the accuracy–efficiency tradeoff for each biometric task when applying INT8 quantization and knowledge distillation for mobile CPU deployment?*

The key finding this study aims to produce: different biometric tasks have fundamentally different sensitivity to quantization. Face embedding quality is highly sensitive to INT8 precision loss because angular margin distances are small. Document quality classification is largely robust. This per-task analysis is the novel empirical contribution.

**Scope:** Two compression techniques are studied — PTQ (INT8)
and knowledge distillation. Quantization-Aware Training (QAT)
and structured pruning are out of scope for the following reasons:

- QAT requires full retraining with simulated INT8 constraints.
  If PTQ accuracy loss is within acceptable bounds (< 2%), QAT
  adds weeks of retraining for negligible gain. Only adopted if
  PTQ loss on face embedding exceeds 3pp — this threshold is
  checked before deciding.
- Structured pruning requires an iterative train–prune–fine-tune
  loop with high failure risk within a thesis timeline.

**Out of scope — startup roadmap (v3.0):**
QAT and structured pruning are natural v3.0 model improvements.
Once Verydent has production latency data from real devices across
West Africa, the compression targets are data-driven rather than
theoretical. QAT recovers accuracy lost from PTQ on face embedding.
Structured pruning reduces model size further for very low-end
devices (2GB RAM Android phones) which represent a significant
portion of the Nigerian market.

---

## 6.1 Optimization Goals

- Identify the minimum model size that preserves > 98% of baseline accuracy per biometric task
- Quantify the accuracy cost of INT8 quantization **per task** — the finding that tasks differ is the thesis contribution
- Determine whether knowledge distillation recovers accuracy that PTQ loses
- Demonstrate end-to-end deployment feasibility on mid-range Android CPU (no GPU/NPU required)

---

## 6.2 Baseline Models

Three models are compressed and benchmarked:

| Model | Architecture | Task | Baseline Accuracy Metric |
|-------|-------------|------|--------------------------|
| Doc Quality | MobileNetV3-Small FP32 | 5-class classification | Top-1 Accuracy |
| Face Embedding | MobileFaceNet FP32 | Metric learning | EER on LFW |
| Liveness | MobileNetV2 FP32 | Binary classification | ACER on OULU-NPU |

Each baseline produces the reference measurement: model size (MB), inference latency (ms on mid-range Android CPU), peak memory usage (MB), and task accuracy.

---

## 6.3 Compression Technique 1 — Post-Training Quantization (PTQ)

**What it does:** Converts FP32 weights (4 bytes per value) to INT8 (1 byte per value).
Result: 4× size reduction with no retraining required. Mobile CPUs run INT8 operations faster than FP32.

**Why accuracy might drop:** INT8 represents 256 discrete values vs. FP32's 4 billion. Rounding introduces small errors in the model weights. For face embedding models using ArcFace loss, these small errors can shift cosine distances enough to affect FAR/FRR. For quality classification, the errors are typically negligible.

**Implementation:** PyTorch dynamic quantization applied to all Linear and Conv2d layers. Calibrated on 500 representative samples from the validation set.

**Expected outcomes per model:**

| Model | Expected Size Reduction | Expected Accuracy Delta |
|-------|------------------------|------------------------|
| Doc Quality | ~4× | < 1% |
| Face Embedding | ~4× | 1–3% EER increase |
| Liveness | ~4× | 1–2% ACER increase |

---

## 6.4 Compression Technique 2 — Knowledge Distillation

**What it does:** Trains a smaller student model to imitate a larger teacher model. The student learns from both the correct labels (hard targets) and the teacher's output probabilities (soft targets). Soft targets carry more information — the teacher's confidence distribution reveals which classes are confused with each other.

**Distillation loss:**
```
L = α × KL(softmax(student/T), softmax(teacher/T)) × T²
  + (1-α) × CrossEntropy(student, hard_labels)
```
Where T = temperature (4.0), α = 0.7

**Student architectures:**
- Doc Quality teacher: MobileNetV3-Small → student: MobileNetV3-Small-050 (half channels)
- Liveness teacher: MobileNetV2-100 → student: MobileNetV2-050

**Why distillation and not pruning:** Structured pruning requires an iterative prune–fine-tune cycle with careful hyperparameter tuning. Knowledge distillation produces a smaller model in a single training run with a well-understood loss function — more reliable within a thesis timeline.

---

## 6.5 Experiment Design — 9 Total Runs

3 models × 3 configurations = 9 experiments:

| Model | Config | Expected Size | Expected Latency | Accuracy |
|-------|--------|--------------|-----------------|---------|
| Doc Quality | FP32 Baseline | ~5MB | ~20ms | reference |
| Doc Quality | INT8 PTQ | ~1.5MB | ~12ms | TBD |
| Doc Quality | Distilled FP32 | ~2MB | ~14ms | TBD |
| Face Embedding | FP32 Baseline | ~2MB | ~80ms | reference |
| Face Embedding | INT8 PTQ | ~0.6MB | ~50ms | TBD |
| Face Embedding | Distilled FP32 | ~0.8MB | ~55ms | TBD |
| Liveness | FP32 Baseline | ~8MB | ~120ms | reference |
| Liveness | INT8 PTQ | ~2.5MB | ~75ms | TBD |
| Liveness | Distilled FP32 | ~3MB | ~80ms | TBD |

All latency measurements are taken on a physical mid-range Android device (Snapdragon 6xx series or equivalent), averaged over 100 inference runs with 10 warmup runs.

---

## 6.6 Input Resolution Experiment

A secondary experiment sweeps input resolution for each model to identify the smallest resolution that maintains acceptable accuracy. This is an independent speed lever from quantization.

| Model | Resolutions Tested |
|-------|-------------------|
| Doc Quality | 224×224, 160×160, 128×128 |
| Face Embedding | 112×112 (fixed — standard for face recognition) |
| Liveness | 128×128, 96×96, 64×64 |
- Liveness can run at low resolution with temporal cues

Method:

- Sweep multiple resolutions
- Measure speed/accuracy
- Choose smallest acceptable resolution

---

## 4.7 Runtime Optimization

### TFLite delegates

- XNNPACK (CPU)
- GPU delegate (optional)

### ONNX Runtime Mobile

- NNAPI / CoreML where available

Key idea:

- Must have a CPU baseline; accelerators are bonus.

---

## 4.8 Measurement & Benchmark Plan (Optimization is Measurable)

For each module, record:

- Model size (MB)
- Latency per inference (ms)
- Peak memory usage (MB)
- Accuracy metric (module-specific)

Example measurement table fields:

- baseline_fp32
- ptq_int8
- qat_int8
- pruned_int8
- distilled_int8

This forms a clean thesis experiment chapter.

---

## 4.9 Recommended Optimization Order (Practical Workflow)

1. Establish baseline accuracy + latency
2. Apply PTQ (fast win)
3. If accuracy drop is large → QAT
4. If latency still high → structured pruning
5. If accuracy degraded → distillation
6. Final tuning: resolution + runtime delegates

---

# 7. Decision Engine — Probabilistic Risk Calibration Model

The Decision Engine is the final AI component in the pipeline. It receives confidence scores from all upstream biometric models and produces a calibrated risk probability used to make the final verification decision.

**This component is an AI contribution, not just a rules engine.** The thesis compares two approaches: a hand-engineered weighted formula (baseline) and a learned probabilistic calibration model (proposed). The learned model is the novel contribution.

---

## 7.1 Problem Formulation

Given a feature vector of model outputs:

```
x = [face_similarity, liveness_score, ocr_confidence, doc_quality_score,
     doc_boundary_confidence, field_validation_score, face_quality_score]
```

Predict: `P(genuine | x)` — the probability that the verification attempt is from a genuine user.

This is a **binary probabilistic classification** problem. The output is a calibrated probability, not just a hard label.

---

## 7.2 Baseline — Hand-Engineered Weighted Score

For comparison, a fixed linear weighted formula is implemented as the baseline:

```
risk_score = 1 − (0.40 × face_similarity
                + 0.30 × liveness_score
                + 0.20 × ocr_confidence
                + 0.10 × doc_quality_score)
```

Limitations of this approach (motivating the learned model):
- Weights are assumed, not derived from data
- Assumes linear separability of the feature space
- Cannot capture feature interactions (e.g., high liveness but very low face similarity should be treated differently than both being moderate)
- Weights do not adapt to different document types or user populations

---

## 7.3 Proposed — Learned Probabilistic Calibration

### Architecture

**Logistic Regression with Platt Scaling** as the primary proposed model:

```
P(genuine | x) = σ(w^T x + b)
```

Where weights `w` are learned from labeled verification session data.

This is intentionally kept simple — the goal is calibrated probabilities, not a complex model. A well-calibrated logistic regression will outperform a poorly-tuned deep model on this low-dimensional input.

### Advanced variant — Gradient Boosted Trees (XGBoost)

For capturing non-linear feature interactions:

```
P(genuine | x) = XGBoost(x) → calibrated with Platt Scaling or Isotonic Regression
```

XGBoost is well-suited because:
- Handles small tabular datasets (verification logs) effectively
- Captures interactions (e.g., face_similarity × liveness_score)
- Output probabilities can be calibrated post-training

### Calibration

Raw model outputs are often not well-calibrated probabilities. Two calibration methods are compared:

- **Platt Scaling**: fit a sigmoid on validation set outputs
- **Isotonic Regression**: non-parametric monotone calibration — more flexible, requires more data

Calibration quality is measured using **Expected Calibration Error (ECE)** and reliability diagrams.

---

## 7.4 Comparison Experiment

| Method | AUC-ROC | ECE | Brier Score | Notes |
|--------|---------|-----|-------------|-------|
| Fixed weights (baseline) | TBD | TBD | TBD | No learning |
| Logistic Regression | TBD | TBD | TBD | Linear learned |
| XGBoost + Platt | TBD | TBD | TBD | Non-linear |
| XGBoost + Isotonic | TBD | TBD | TBD | Best calibration |

---

## 7.5 Inputs to the Decision Engine

Signals collected from earlier pipeline stages (all normalized 0–1):

Document signals: `doc_quality_score`, `doc_boundary_confidence`

OCR signals: `ocr_confidence`, `field_validation_score`

Face verification signals: `face_similarity`, `face_quality_score`

Liveness signals: `liveness_score`, `challenge_success`

Optional device signals: `attempt_count`, `device_fingerprint_risk`, `ip_risk`

---

## 7.6 Decision Thresholds

Example formulation:

risk_score = 1 − (w1 * face_similarity
                 + w2 * liveness_score
                 + w3 * ocr_confidence
                 + w4 * doc_quality_score)

Where:

w1 + w2 + w3 + w4 = 1

Example weights:

- face similarity: 0.40
- liveness score: 0.30
- OCR confidence: 0.20
- document quality: 0.10

Interpretation:

- High signal confidence → low risk
- Low signal confidence → high risk

---

## 7.7 Decision Thresholds

The risk score determines the final outcome.

Example thresholds:

Accept

risk_score < 0.30

Manual Review

0.30 ≤ risk_score ≤ 0.60

Reject

risk_score > 0.60

Thresholds can be tuned during evaluation experiments.

---

## 7.8 Rule-Based Overrides

Certain conditions override the numeric score.

Examples:

Hard Reject

- liveness_score < minimum threshold
- face_similarity extremely low
- document not detected

Manual Review

- OCR field validation failed
- ID number format invalid

This hybrid approach (ML signals + rules) is typical in real KYC systems.

---

## 7.9 Explainability Signals

The system records a structured explanation for each decision.

Example output:

{

"decision": "manual_review",

"risk_score": 0.42,

"signals": {

"face_similarity": 0.71,

"liveness_score": 0.82,

"ocr_confidence": 0.55,

"doc_quality": 0.88

},

"reason_codes": ["LOW_OCR_CONFIDENCE"]

}

Benefits:

- Easier debugging
- Easier system evaluation
- Useful for manual review workflows

---

## 7.10 Logging and Audit Records

Each verification attempt produces an audit record containing:

- decision
- risk_score
- signal values
- timestamp
- model_version
- device metadata (optional)

These logs support evaluation experiments and reproducibility.

---

# 6. Evaluation Benchmark Design

This section defines how the KYC system will be **empirically evaluated**. The evaluation demonstrates that the proposed pipeline meets performance, accuracy, and mobile deployment goals.

The evaluation is performed at **two levels**:

1. **Module-level evaluation** (OCR, face verification, liveness)
2. **End-to-end system evaluation** (full KYC pipeline)

---

## 6.1 Dataset Sources

The evaluation uses a mixture of **public datasets** and **synthetic datasets** generated by the system.

### Public datasets

Document datasets

- MIDV-500
- ICDAR document datasets

Face datasets

- LFW (evaluation only)

Liveness datasets

- OULU-NPU
- CASIA-FASD

These datasets allow benchmarking against established academic metrics.

---

### Synthetic datasets

The Synthetic Dataset Generator produces:

- Synthetic ID documents
- Augmented document images
- Controlled lighting / blur / perspective distortions

Synthetic data helps simulate real-world camera capture conditions while avoiding privacy issues.

---

## 6.2 Dataset Splitting Strategy

Datasets are divided into three subsets.

Training set

Used for model training and optimization.

Validation set

Used for hyperparameter tuning and model selection.

Test set

Used only for final evaluation.

Typical split:

- Training: 70%
- Validation: 15%
- Test: 15%

No overlap is allowed between splits to avoid leakage.

---

## 6.3 OCR Evaluation Metrics

OCR performance is evaluated using:

Character Error Rate (CER)

CER = (Substitutions + Insertions + Deletions) / Total characters

Field extraction accuracy

Percentage of correctly extracted structured fields such as:

- Name
- ID number
- Date of birth

---

## 6.4 Face Verification Metrics

Face verification performance is evaluated using biometric metrics.

False Acceptance Rate (FAR)

Probability that an impostor is incorrectly accepted.

False Rejection Rate (FRR)

Probability that a legitimate user is incorrectly rejected.

Receiver Operating Characteristic (ROC)

Plots FAR vs True Positive Rate across thresholds.

These metrics allow threshold tuning for the decision engine.

---

## 6.5 Liveness Detection Metrics

Liveness systems are evaluated using ISO-standard metrics.

Attack Presentation Classification Error Rate (APCER)

Measures how often spoof attacks are incorrectly classified as real.

Bona Fide Presentation Classification Error Rate (BPCER)

Measures how often genuine users are incorrectly rejected.

Average Classification Error Rate (ACER)

ACER = (APCER + BPCER) / 2

These metrics quantify robustness against spoofing attacks.

---

## 6.6 Mobile Performance Metrics

Since the system targets mobile deployment, runtime performance must also be evaluated.

Key measurements:

Model size (MB)

Inference latency (ms)

Peak memory usage (MB)

Battery impact (optional measurement)

Target values:

- Model size under ~50MB total
- Individual inference under ~200ms
- End-to-end verification under ~5 seconds

---

## 6.7 Optimization Experiments

A series of experiments evaluate the effect of model optimization techniques.

Experiments compare:

Baseline FP32 models

Post-training quantized models (INT8)

Quantization-aware trained models

Pruned models

Distilled models

Each experiment records:

- Accuracy change
- Latency change
- Model size reduction

These results demonstrate the benefits of mobile optimization.

---

## 6.8 End-to-End System Evaluation

The full pipeline is evaluated using simulated verification sessions.

Test scenarios include:

- Normal document capture
- Low lighting conditions
- Blurred images
- Spoof attempts
- Face mismatch cases

Metrics recorded:

- Overall verification success rate
- False acceptance rate (system level)
- False rejection rate (system level)
- Average verification time

---

# 7. System Architecture & Data Flow (Edge/Server Split + Privacy)

This section defines the end-to-end architecture for the KYC system and clarifies:

- What runs on the **mobile device**
- What runs on the **backend**
- What data is transmitted
- What data is stored and for how long

Primary design principle:

- **Edge-first** for privacy + UX
- **Server fallback** for heavy processing (especially OCR) and governance (audit/manual review)

---

## 7.1 High-Level Components

Mobile App (Flutter)

- Camera capture + UX
- On-device ML inference (TFLite / ONNX)
- Local pre-processing (crop/warp)
- Generates verification signals
- Enforces layered architecture (Data, Domain, Presentation) utilizing Riverpod for scalable state management.

API Gateway

- Authentication
- Rate limiting
- Request validation

KYC Processing Service

- OCR service (optional/fallback)
- Decision engine
- Logging + audit
- Manual review routing

Storage

- Verification records (scores, decision, reason codes)
- Optional: encrypted embeddings
- Optional: encrypted images for manual review

Admin / Manual Review Console

- Review queue
- Case decision + notes
- Audit trail access (limited)

---

## 7.2 Data Flow: Happy Path

### Step 1 — Document capture (mobile)

- Mobile runs quality checks in real-time
- User captures a high-quality frame

Output:

- normalized_doc_image (local)
- doc_quality_score

---

### Step 2 — Document processing (mobile)

- Document boundary detection
- Perspective correction
- Orientation normalization

Output:

- normalized_doc_image
- doc_boundary_confidence

---

### Step 3 — OCR (two-mode)

**Mode A: On-device OCR**

- OCR runs locally
- Extracts fields + confidence

**Mode B: Server OCR fallback**

- Mobile uploads normalized_doc_image
- Server returns extracted fields + confidence

Output:

- extracted_fields
- ocr_confidence
- field_validation_score

---

### Step 4 — Selfie capture + face verification (mobile)

- Capture selfie burst
- Select best frame
- Extract face embedding
- Extract face from document image
- Compute similarity

Output:

- face_similarity
- face_quality_score

---

### Step 5 — Liveness detection (mobile)

- Passive + active checks

Output:

- liveness_score
- challenge_success

---

### Step 6 — Decision request (mobile → server)

Mobile sends **signals only** (privacy-first):

- doc_quality_score
- ocr_confidence
- field_validation_score
- face_similarity
- liveness_score
- reason_codes (if any)
- model_version + app_version

Server computes (or verifies) final decision and stores audit record.

---

## 7.3 What Data is Transmitted

Default transmission policy:

- Transmit **scores + extracted fields** (masked where possible)
- Do not transmit selfie video
- Do not transmit raw camera stream

If server OCR fallback is used:

- Transmit only normalized document image
- Never transmit full raw frame sequence

---

## 7.4 What Data is Stored (Retention Policy)

Recommended thesis-safe retention:

Always store (low sensitivity)

- decision
- risk_score
- per-module scores
- reason codes
- timestamps
- model_version

Optionally store (higher sensitivity)

- face embedding template (encrypted)
- document fingerprint hash

Store only for manual review (highest sensitivity)

- encrypted document image
- encrypted selfie best-frame

Retention guidance:

- Default: no raw biometrics stored
- Manual review artifacts: short retention (e.g., 7–30 days)

---

## 7.5 Security Controls (Architecture Level)

Transport security

- TLS for all network traffic

Access control

- Role-based access for admin console

Abuse prevention

- Rate limiting
- Attempt caps per user/device

Audit logging

- Append-only verification log
- Record model versions for reproducibility

---

## 7.6 System Failure Modes

Mobile-side failures:

- QUALITY_FAIL
- DOC_NOT_FOUND
- FACE_NOT_FOUND
- LIVENESS_FAIL

Server-side failures:

- OCR_SERVICE_DOWN
- DECISION_TIMEOUT

Resilience strategy:

- On-device retries for capture
- Server OCR fallback if on-device OCR fails
- Manual review path when uncertain

---

# 8. Implementation Roadmap (Milestones + Thesis Deliverables)

This section defines the practical implementation plan for building and evaluating the KYC system. The roadmap breaks development into clear stages so the project progresses from prototype → optimized mobile system → evaluated research artifact.

---

## 8.1 Phase 1 — Dataset Preparation

Goals:

- Prepare datasets for all modules
- Implement the Synthetic Dataset Generator

Tasks:

- Implement ID template system
- Generate synthetic identity documents
- Apply augmentation (blur, glare, perspective)
- Prepare public dataset integrations

Deliverables:

- Synthetic dataset generator code
- Generated document dataset
- Train/validation/test splits

---

## 8.2 Phase 2 — Baseline Model Development

Goals:

Train initial baseline models before optimization.

Modules:

- Document quality classifier
- Document detector
- OCR pipeline
- Face embedding model
- Liveness detection model

Tasks:

- Train baseline models (FP32)
- Evaluate module-level metrics

Deliverables:

- Baseline models
- Initial benchmark results

---

## 8.3 Phase 3 — Model Optimization

Goals:

Apply mobile optimization techniques.

Techniques:

- Post-training quantization
- Quantization-aware training
- Structured pruning
- Knowledge distillation

Tasks:

- Compare optimized vs baseline models
- Measure size, latency, memory

Deliverables:

- Optimized models (INT8)
- Optimization experiment report

---

## 8.4 Phase 4 — Mobile Integration

Goals:

Deploy optimized models on a mobile application.

Tasks:

- Export models to TFLite / ONNX Runtime
- Implement inference pipeline in Flutter
- Integrate camera capture
- Implement real-time quality checks

Deliverables:

- Working mobile KYC prototype
- On-device inference pipeline

---

## 8.5 Phase 5 — Backend Integration

Goals:

Implement backend services required for verification and logging.

Tasks:

- API gateway
- OCR fallback service
- Decision engine service
- Verification record storage

Deliverables:

- KYC processing service
- Logging and audit system

---

## 8.6 Phase 6 — System Evaluation

Goals:

Evaluate the full KYC pipeline.

Tasks:

- Run module-level experiments
- Run optimization experiments
- Measure end-to-end latency
- Test spoof scenarios

Deliverables:

- Benchmark tables
- ROC curves
- System performance report

---

## 8.7 Phase 7 — Thesis Documentation

Goals:

Prepare the final academic report.

Tasks:

- Document system design
- Present experiment results
- Analyze tradeoffs
- Discuss limitations and future work

Deliverables:

- Master's thesis document
- System demonstration

---

# 9. Critical Gaps, Design Improvements & Alternative Approaches

This section documents identified engineering gaps, design weaknesses, and alternative approaches that should be addressed before the system is considered production-ready or academically complete.

---

## 9.0.1 Gap 1 — Decision Engine Weight Justification

### Problem

The current decision engine uses fixed, manually assigned weights:

- face_similarity: 0.40
- liveness_score: 0.30
- ocr_confidence: 0.20
- doc_quality_score: 0.10

These values are assumptions, not learned from data. There is no
justification for why face similarity should be exactly 40% of the
risk signal versus 35% or 45%.

### What This Thesis Does

The thesis compares three decision engine approaches on simulated
session data:

1. Fixed weights (baseline)
2. Logistic regression (learns optimal weights from data)
3. XGBoost (non-linear combination)

The comparison produces a results table with AUC-ROC, Brier Score,
and ECE for each variant. The thesis contribution is the comparison
and the calibration analysis — not a claim that the fixed weights
are optimal.

**Scope boundary:** Training on real labelled verification outcomes
(genuine sessions confirmed by human reviewers) requires production
data that does not exist during thesis development. Simulated session
data is used instead, with this limitation explicitly documented.

**Out of scope — startup roadmap (v3.0):**
Retraining the decision engine on real production session outcomes
is a v3.0 data flywheel feature. Once Verydent has thousands of
verified sessions with confirmed outcomes, the logistic regression
model is retrained on real labels and the weights become empirically
justified rather than assumed.

---

## 9.0.2 Gap 2 — Fairness and Bias Evaluation

### Problem

Biometric systems are known to produce disparate error rates across
demographic groups. Face verification and liveness detection models
can show higher false rejection rates for darker skin tones and
performance gaps across age groups and gender. Any thesis in 2025/2026
that does not address this will face examiner scrutiny.

### What This Thesis Does

A fairness evaluation is conducted on the available demographic
subgroups within LFW and CelebA-Spoof. Both datasets have
demographic annotations available. The thesis reports:

- FAR and FRR broken down by available demographic subgroups
- Maximum performance gap across groups (equalized odds metric)
- Honest acknowledgment of dataset demographic limitations

**Scope boundary:** LFW and CelebA-Spoof have known demographic
imbalances. A fully representative fairness evaluation requires
a purpose-built diverse dataset which does not exist publicly
for Nigerian document verification. The thesis reports what the
available data supports and explicitly acknowledges the limitation.

**What is not done in this thesis:**
Training data rebalancing, fairness-aware loss functions, and
threshold adjustment per subgroup require more data and more
training iterations than the thesis timeline allows. These are
noted as future work.

**Out of scope — startup roadmap (v3.0):**
Verydent v3.0 includes fairness monitoring on production data
by demographic group. Real session data from African users
provides the demographic diversity that public datasets cannot.
Active learning labels from manual review decisions become
training data for demographic rebalancing.

---

## 9.0.3 Gap 3 — Synthetic-to-Real Domain Gap Is Underestimated

### Problem

The system is trained primarily on synthetic ID documents. The spec acknowledges this as a limitation but does not propose a strategy to measure or close the gap.

In practice, synthetic-to-real transfer failures are one of the most common reasons document AI systems underperform in production. Specific failure modes include:

- Font rendering differences between PIL-generated text and real printed fonts
- Holographic and security feature patterns not present in synthetic documents
- Paper texture, lamination artifacts, and physical wear not captured by augmentation
- Lighting gradients on curved/bent real documents vs. flat synthetic renders

### Recommended Fix

**Quantify the domain gap explicitly** and report it honestly rather than attempting to close it with domain adaptation.

Approach:
1. Train models on synthetic data only
2. Evaluate on a small held-out set of real document images (50–100 samples is sufficient for gap quantification)
3. Report the accuracy drop: synthetic test set accuracy vs. real document accuracy
4. This becomes a measured limitation with concrete numbers rather than a vague caveat

**Note on DANN:** Domain Adversarial Neural Networks were evaluated as a gap-closing approach. DANN was not adopted because adversarial training loops are notoriously unstable — the domain classifier and feature extractor frequently fail to converge together within a constrained training budget. The honest measurement approach produces a more reproducible and academically defensible result. Domain adaptation remains a natural direction for future work.

Expected experiment:

| Training Data | Test Set | Accuracy | Notes |
|--------------|----------|----------|-------|
| Synthetic only | Synthetic test | TBD | Upper bound |
| Synthetic only | Real documents | TBD | Domain gap measured |

---

## 9.0.4 Security Analysis — Client-Side Score Generation and Architecture Decision

### Background — Why This Was Evaluated

During architecture design, an edge-first approach was considered: all biometric
inference (face embedding, liveness, OCR) runs on-device, and only scalar confidence
scores are transmitted to the server for the final decision. This approach is used
by several production mobile systems and has genuine advantages in privacy and
connectivity requirements.

The data flow under edge-first would be:

```
mobile → { face_similarity: 0.85, liveness_score: 0.91, ... } → server → decision
```

### The Attack Vector That Ruled It Out

A technically capable attacker with a rooted Android device and network interception
tools (Frida dynamic instrumentation framework, Charles Proxy, mitmproxy) can
intercept the outgoing HTTPS payload and replace genuine model-computed scores
with fabricated values before transmission:

```
1. Attacker roots device or installs interception certificate
2. Intercepts POST /api/v1/verify/submit/ before it leaves the device
3. Replaces { face_similarity: 0.31, liveness_score: 0.18 }
        with { face_similarity: 0.97, liveness_score: 0.95 }
4. Forwards modified payload — server receives fabricated scores
5. Decision engine issues ACCEPT on fraudulent input
```

This is not a theoretical risk. It is documented in mobile security literature
and reproducible with freely available tools by any technically capable adversary.
Crucially, no combination of mitigations applied to a client-score architecture
fully eliminates it — a determined attacker who reverse-engineers the signing
mechanism can hook into the inference layer before signing occurs.

### The Architecture Decision

This analysis led to the adoption of a **server-authoritative hybrid** architecture
(described in Section 3), where:

- The mobile device handles pre-screening and UX only — document quality feedback,
  boundary detection, face detection, and active liveness challenges
- All biometric inference that feeds the decision engine runs server-side from
  encrypted uploaded images — face embedding, face similarity, passive liveness,
  OCR, and document quality scoring

This eliminates the payload tampering vulnerability entirely. There are no
client-generated biometric scores to fabricate because the server computes all
scores from the raw encrypted images directly.

**The connectivity concern** — that server-side inference requires image upload
over potentially poor mobile data — is addressed by the mobile pre-screening
layer. The quality TFLite model on-device ensures the user only uploads an image
that meets quality thresholds, keeping the upload payload small (~150–300KB
compressed) and reducing failed sessions from poor image quality before any
data is transmitted.

**The cost concern** — that server-side inference adds GPU compute cost — is
addressed by the compression study (Section 6). INT8-quantised ONNX models
running on standard CPU inference achieve 30–80ms per verification, eliminating
the need for GPU instances and keeping server cost at $0.04–0.07 per verification.

### Remaining Security Controls

Two controls protect the integrity of what the mobile device sends to the server:



Score payloads are signed with an ECDSA-P256 private key stored in Android's Hardware-Backed Keystore (Trusted Execution Environment — TEE). The TEE is a hardware-isolated secure enclave on the device SoC. Private keys stored in the TEE cannot be extracted even from a fully rooted device — the key never leaves the secure enclave in plaintext form.

At first app launch, the SDK generates a signing keypair and registers the public key with the Verydent backend. Every verification payload is signed before transmission. The backend verifies the signature against the registered public key before processing any scores. A payload that has been modified in transit will not produce a valid signature and is rejected with HTTP 403.

```kotlin
// Android — sign score payload with TEE-backed key
val privateKey = keyStore.getKey("kyc_signing_key", null) as PrivateKey
val payloadBytes = Json.encodeToString(scores).toByteArray()
val signature = Signature.getInstance("SHA256withECDSA").apply {
    initSign(privateKey)
    update(payloadBytes)
}.sign()
```

```python
# Backend — reject payloads with invalid signatures
def verify_signature(payload_json: str, signature_b64: str, public_key_pem: bytes) -> bool:
    public_key = serialization.load_pem_public_key(public_key_pem)
    try:
        public_key.verify(
            base64.b64decode(signature_b64),
            payload_json.encode(),
            ec.ECDSA(hashes.SHA256())
        )
        return True
    except InvalidSignature:
        return False  # Payload was modified — reject
```

This layer directly defeats proxy-based payload modification. An attacker who intercepts and modifies the payload cannot produce a valid signature without the private key, which they cannot extract from the TEE.

---

**Layer 2 — Android Play Integrity API**

Every verification request includes a Play Integrity attestation token generated immediately before submission. The backend verifies this token with Google's Play Integrity servers to confirm:

- The app binary has not been modified (APK tamper check)
- The app is a genuine installation from Google Play (not sideloaded)
- The device passes basic integrity checks (not a known compromised device)
- The device meets strong integrity standards (not rooted, no known boot image modifications)

```python
# Backend — verify Play Integrity token before trusting payload
def verify_play_integrity(token: str, nonce: str) -> dict:
    response = requests.post(
        'https://playintegrity.googleapis.com/v1/decodeIntegrityToken',
        json={'integrity_token': token},
        headers={'Authorization': f'Bearer {google_access_token}'}
    )
    result = response.json()
    device_verdict = result['tokenPayloadExternal']['deviceIntegrity']
    app_verdict    = result['tokenPayloadExternal']['appIntegrity']

    return {
        'device_ok': 'MEETS_STRONG_INTEGRITY' in device_verdict.get('deviceRecognitionVerdict', []),
        'app_ok':    app_verdict.get('appRecognitionVerdict') == 'PLAY_RECOGNIZED',
        'nonce_ok':  result['tokenPayloadExternal']['requestDetails']['nonce'] == nonce,
    }
```

This layer catches rooted devices and modified APKs — the two primary attack prerequisites for Frida-based instrumentation.

---

### Security Coverage Summary

| Attack Vector | Detected By | Response |
|---|---|---|
| Proxy interception + image substitution | ECDSA signature fails | HTTP 403, session terminated |
| Rooted device | Play Integrity fails | HTTP 403, device flagged |
| Modified APK | Play Integrity fails | HTTP 403, app flagged |
| Fabricated biometric scores | Not applicable — server computes all scores from raw images | N/A |
| Photo / print attack | Passive liveness model (server) + active challenge (mobile) | REJECT |
| Deepfake video replay | Active challenge requires real-time blink + head turn | REJECT |
| Nation-state level device compromise | Outside scope | Not addressed |

The key entry in this table is row 4. In a client-score architecture, fabricated scores are the primary attack. In this server-authoritative architecture, fabricated scores are structurally impossible — there are no client-generated scores to fabricate.

### Thesis Implementation Scope

ECDSA payload signing is implemented and tested on a development
device using the Android Keystore API. Play Integrity integration
code is provided in full in DOC3 (Flutter) and DOC2 (Django backend).

**Out of scope — thesis prototype:**
Deployment of Play Integrity requires a production Google Play
Console account with a published app. This is a deployment
prerequisite, not a research gap. The code is complete and
tested. Production activation is a one-step configuration
change at launch.

**iOS equivalent — out of scope for thesis:**
iOS uses the Secure Enclave for hardware-backed key storage and
the DeviceCheck/App Attest API as the Play Integrity equivalent.
The thesis targets Android only. iOS support is not claimed.

**Out of scope — startup roadmap (v1.1):**
Play Integrity production activation and iOS App Attest
implementation are the two primary security hardening tasks
in Verydent v1.1 (Month 6–7). Both are deployment tasks with
complete code — not research problems. Enterprise clients require
both before signing commercial contracts.

This security analysis constitutes a contribution of the thesis: a rigorous evaluation of edge-first vs server-authoritative architectures for mobile KYC systems, leading to a justified architecture decision with documented reasoning. The analysis demonstrates that the commonly cited advantages of edge-first inference (privacy, connectivity, cost) can be preserved in a server-authoritative hybrid through pre-screening on-device and compressed server inference — without accepting the payload tampering vulnerability that edge-first architectures cannot fully resolve.


---

## 9.0.5 Gap 5 — Deepfake Liveness Attacks

### Problem

Full deepfake defense is a research area of its own. The liveness
model trained on CelebA-Spoof covers print attacks, screen replay,
and video replay. Face-swap deepfakes are a different attack class
not represented in the training data.

### What This Thesis Does

A minimum baseline experiment is included:

1. Generate a small set of face-swap samples using open-source
   FaceSwap or DeepFaceLab
2. Run the existing liveness model against these samples
3. Report the attack success rate honestly

This does not claim deepfake defense. It quantifies the current
system's vulnerability — which is academically honest and more
useful than silence on the topic.

| Attack Type | APCER | Notes |
|---|---|---|
| Print attack | TBD | Primary evaluation |
| Screen replay | TBD | Primary evaluation |
| Video replay | TBD | Primary evaluation |
| Basic deepfake (FaceSwap) | TBD | Baseline vulnerability only |

**Out of scope — startup roadmap (v3.0):**
Deepfake-aware liveness is a v3.0 model improvement. Once
Verydent has real spoof attempt data from production sessions,
the liveness model is retrained with deepfake samples included.
Frequency-domain analysis (FFT artifacts in GAN faces) is the
most promising technical direction for the next model version.

---

## 9.0.6 Design Decision — OCR Strategy: ML Kit over Custom Transformer Models

### Why TrOCR and Donut Were Evaluated and Not Adopted

During the design phase, two transformer-based OCR approaches were evaluated:

**TrOCR** (Microsoft) — vision encoder + language decoder fine-tuned on document crops.
**Donut** (Clova AI) — end-to-end document understanding, outputs structured JSON from full document image.

Both were ultimately not adopted for the following reasons:

TrOCR at ~334MB is too large for on-device inference and requires server-side deployment, creating an additional service dependency. Donut at ~200MB has similar constraints plus 24–48 hours of fine-tuning time with high risk of training instability on the synthetic dataset.

Most critically: both approaches require the synthetic document dataset to produce the training quality needed — and a model trained purely on synthetic documents will underperform Google ML Kit which has been trained on billions of real documents.

**Adopted approach:** Google ML Kit Text Recognition v2 on-device (primary) + Tesseract server fallback. This combination provides production-grade OCR accuracy with zero training cost, zero model size overhead, and on-device privacy. The thesis contribution is the field extraction, confidence scoring, and validation pipeline built on top — not the OCR engine itself.

This decision mirrors the practice of commercial KYC systems (Jumio, Sumsub) and is explicitly documented in the thesis as an engineering decision with full justification.

---

## 9.0.7 Alternative Approach 2 — Learned Risk Calibration vs. Fixed Weights

See Gap 1 (Section 9.0.1) for full details.

Summary: train a logistic regression calibration model on top of module scores instead of using fixed manually assigned weights. This is a small implementation change with significant academic and practical value.

---

## 9.0.8 Design Decision — Test-Time Adaptation Not Adopted

Test-Time Adaptation (TTA) and Test-Time Training (TTT) techniques were considered for improving generalisation to unseen document types. These approaches briefly fine-tune model parameters at inference time using self-supervised auxiliary tasks.

These were not adopted because:
- TTA is highly experimental with limited published success on production document recognition systems
- Fine-tuning at inference time adds latency that conflicts with the < 5s end-to-end target
- Risk of no measurable improvement within a constrained thesis timeline

**Adopted alternative:** The synthetic-to-real domain gap is explicitly measured and reported (Section 9.0.3). Honest quantification of the gap is more academically reproducible than an experimental adaptation technique that may not converge. TTA is documented in Future Work (Section 11.3) as a concrete research extension.

---

## 9.0.9 Startup Readiness Gap — Cost-Per-Verification Benchmarking

If this system is intended to evolve into a commercial product (KYC-as-a-Service), the thesis should include a **cost-per-verification analysis** to establish business viability.

Competitors charge $1–$5 per verification (Jumio, Onfido, Sumsub, Veriff). A cost analysis should estimate:

- Cloud compute cost per verification (server OCR, decision engine)
- Mobile inference cost is effectively zero (runs on user's device)
- Storage cost per verification record

Target: demonstrate cost-per-verification under $0.50 to establish a viable price margin against incumbents.

This analysis belongs in the thesis conclusion and directly supports a future commercialization narrative.

---

# 10. Expected AI Contributions & Limitations

## 10.1 Original AI Research Contributions

This thesis makes the following **original contributions to the AI research literature**:

### Contribution 1 — Per-Task Compression Sensitivity Study

Existing compression studies apply quantization and distillation to image classification benchmarks. This thesis applies INT8 PTQ and knowledge distillation across three distinct biometric tasks — document quality classification, face embedding, and liveness detection — and measures task-specific accuracy sensitivity to each technique.

**Why this is novel:** Face embedding quality is highly sensitive to INT8 precision loss because angular margin distances are small. Document quality classification is largely robust. This per-task sensitivity analysis has not been systematically published for a complete mobile KYC pipeline.

### Contribution 2 — Passive Liveness CNN with Active Challenge-Response Fusion

The liveness system combines a MobileNetV2 binary classifier trained on OULU-NPU for passive texture-based anti-spoofing with active challenge-response (blink, head-turn) via Google ML Kit Face Detection. Both components are benchmarked against spoof attack categories with APCER/BPCER reported for passive-only and passive+active configurations.

**Why this is novel:** Most published mobile liveness papers evaluate passive OR active signals in isolation. The explicit combination and independent benchmarking of both components is the contribution.

### Contribution 3 — Calibrated Probabilistic Decision Engine vs. Engineered Weights

A hand-engineered weighted risk formula (baseline) is formally compared against logistic regression and XGBoost with isotonic calibration. Evaluation uses ECE, reliability diagrams, and Brier score — calibration-specific metrics not commonly applied to KYC decision fusion literature.

### Contribution 4 — Synthetic-to-Real Domain Gap Quantification

Accuracy degradation when transitioning from synthetic to real document test sets is explicitly measured and reported as a concrete number, providing an honest and reproducible limitation assessment.

### Contribution 5 — Security-First Hybrid Mobile Architecture with Justified Design Decision

A server-authoritative hybrid architecture is designed, implemented, and formally justified through a comparative security analysis of edge-first vs server-side inference. The analysis identifies payload tampering as an unresolvable vulnerability in client-score architectures, leading to the adoption of server-side authoritative inference. The commonly cited disadvantages of server-side inference — connectivity dependency, privacy regression, and cost — are each addressed architecturally: mobile pre-screening reduces upload failures, image encryption protects biometric data in transit, and model compression (Section 6) enables CPU-based server inference at $0.04–0.07 per verification. Cryptographic controls (ECDSA signing, Play Integrity) protect image upload integrity. This architecture and its justification constitute a documented design contribution applicable to any mobile biometric verification system.

---

## 10.2 Limitations

**Synthetic data ceiling:**
Models trained on synthetic documents cannot capture holographic
security features, physical wear, or lamination artifacts. The
synthetic-to-real gap is quantified but not closed.
*Startup path (v3.0):* Retrain on real document images collected
from production verification sessions.

**Deepfake liveness boundary:**
The liveness model covers print, screen, and video replay attacks.
Advanced face-swap deepfakes are a known open problem. A baseline
attack success rate is reported but a full defense is out of scope.
*Startup path (v3.0):* Frequency-domain analysis branch added
to liveness model. Real spoof attempts from production become
training data.

**Closed-set dataset bias:**
Public datasets (OULU-NPU, CASIA-FASD, LFW) have known demographic
imbalances. Fairness evaluation is conducted but training data
rebalancing is out of scope for this thesis.
*Startup path (v3.0):* Fairness monitoring on production data
by demographic group. Active learning labels from manual review
become rebalancing training data.

**Single-country document scope:**
Templates cover Nigerian NIN smart card only. Multi-country
generalisation requires additional field extractor templates
and real-world testing per document type. No model retraining
is needed — templates are rule-based.
*Startup path (v1.2):* Document expansion to Nigerian Voter Card,
Nigerian Passport, Ghanaian Ghana Card, Kenyan National ID,
South African Smart ID. Each is a half-day template addition.

**No database verification:**
The system cannot verify that a NIN number actually exists in
the NIMC database. Format validation catches lazy fraud but a
correctly formatted fake NIN passes field validation. Full
document authenticity requires government API integration.
*Startup path (v2.1):* NIMC API integration for NIN lookup
when regulatory access is available. Watchlist and sanctions
screening via a compliance API partner.

**Android-only:**
The Flutter SDK targets Android. iOS is not tested or supported
in the thesis prototype. Play Integrity has no direct iOS
equivalent — iOS uses App Attest.
*Startup path (v1.1):* iOS App Attest + Secure Enclave signing.
Full parity with Android security model.

**Mobile hardware variance:**
Latency benchmarks are conducted on representative mid-range
and flagship Android devices. Very low-end device performance
(2GB RAM, Snapdragon 400-series) is not benchmarked.
*Startup path (v3.0):* Structured pruning for very low-end
devices after production latency data is collected.

---

## 10.3 Future Work

Each item below is explicitly designated as out of scope for
this thesis with a clear reason. Each maps to a specific
Verydent product version where applicable.

**QAT and structured pruning** *(startup v3.0)*
If PTQ INT8 accuracy loss on face embedding exceeds 3pp,
QAT is the natural next step. Structured pruning targets
very low-end devices. Both require more training iteration
than the thesis timeline allows.

**Deepfake-aware liveness** *(startup v3.0)*
Extend liveness with a frequency-domain analysis branch
targeting FFT artifacts in GAN and diffusion-generated faces.
Requires a deepfake-specific training dataset not available
during thesis development.

**iOS App Attest + Secure Enclave** *(startup v1.1)*
Direct iOS equivalent of the Android Play Integrity +
Keystore security layer. Deployment task — code complete,
requires production App Store account.

**Multi-country document templates** *(startup v1.2)*
Field extractor templates for Nigerian Voter Card, Nigerian
Passport, Ghanaian Ghana Card, Kenyan National ID, South African
Smart ID. Each is a half-day rule-based addition. No model
retraining required.

**Government database verification** *(startup v2.1)*
NIMC API integration for NIN existence lookup. Sanctions and
watchlist screening via compliance API partner. Requires
regulatory access agreements not available to a thesis prototype.

**Fairness-aware retraining** *(startup v3.0)*
Training data rebalancing and fairness-aware loss functions
once production session data provides demographic diversity
beyond what public datasets offer.

**Test-time adaptation for unseen documents** *(research)*
Fine-tune model parameters at inference time using self-supervised
auxiliary tasks. Highly experimental — not adopted because
adversarial training loops are unstable within a constrained
training budget. Natural academic follow-on study.

**Federated learning** *(research)*
Train face embedding and liveness models across distributed
devices without centralising biometric data. Long-term privacy
architecture direction. Requires significant infrastructure
investment beyond thesis or early startup scope.

**Self-supervised document pretraining** *(research)*
Pretrain document models on synthetic corpus using masked
autoencoders (MAE) for better synthetic-to-real alignment.
Natural follow-on to the domain gap finding in Section 9.0.3.

---

**This document represents the full AI research specification for the Master's Thesis in Artificial Intelligence.**

---

# 11. Experiment Plan & Evaluation Tables

This section defines the concrete experiments conducted to demonstrate the system's effectiveness and optimization tradeoffs.

---

## 11.1 Compression Study Experiments (Core Chapter)

3 models × 3 configurations = 9 total experiments:

| Model | Variant | Size (MB) | Latency (ms) | Accuracy | Notes |
|-------|---------|-----------|--------------|---------|-------|
| Doc Quality | FP32 Baseline | TBD | TBD | TBD | Reference |
| Doc Quality | INT8 PTQ | TBD | TBD | TBD | Target: 4× smaller |
| Doc Quality | Distilled FP32 | TBD | TBD | TBD | Smaller architecture |
| Face Embedding | FP32 Baseline | TBD | TBD | TBD | Reference EER |
| Face Embedding | INT8 PTQ | TBD | TBD | TBD | Sensitivity expected |
| Face Embedding | Distilled FP32 | TBD | TBD | TBD | |
| Liveness | FP32 Baseline | TBD | TBD | TBD | ACER reference |
| Liveness | INT8 PTQ | TBD | TBD | TBD | |
| Liveness | Distilled FP32 | TBD | TBD | TBD | |

Example results table:

| Model Variant | Size (MB) | Latency (ms) | Accuracy | Notes |
|---------------|-----------|--------------|----------|------|
| Baseline FP32 | 28 MB | 180 ms | 0.94 | Reference model |
| INT8 PTQ | 7 MB | 110 ms | 0.92 | 4x smaller |
| INT8 QAT | 7 MB | 115 ms | 0.935 | Accuracy recovered |
| Pruned + INT8 | 5 MB | 90 ms | 0.93 | Best latency |

---

## 11.2 Input Resolution Experiments

Model performance will be evaluated under multiple input resolutions.

Example experiment:

| Resolution | Latency (ms) | Accuracy |
|-----------|--------------|----------|
| 224x224 | 150 ms | 0.95 |
| 160x160 | 110 ms | 0.94 |
| 128x128 | 85 ms | 0.92 |

Goal:

Identify the smallest resolution that maintains acceptable accuracy.

---

## 11.3 Face Verification Threshold Experiments

Face verification performance depends on similarity threshold selection.

Experiments will sweep thresholds and measure:

- FAR (False Acceptance Rate)
- FRR (False Rejection Rate)

Example table:

| Threshold | FAR | FRR |
|----------|-----|-----|
| 0.55 | 0.06 | 0.02 |
| 0.65 | 0.03 | 0.04 |
| 0.75 | 0.01 | 0.08 |

The chosen threshold balances security and usability.

---

## 11.4 Liveness Detection Attack Experiments

Spoof attacks will be simulated using several scenarios:

- Printed photo attacks
- Screen replay attacks
- Video replay attacks

Metrics recorded:

- APCER
- BPCER
- ACER

Example table:

| Attack Type | APCER |
|------------|------|
| Print attack | 0.05 |
| Screen replay | 0.07 |
| Video replay | 0.09 |

---

## 11.5 End-to-End Pipeline Experiments

Full KYC verification sessions will be simulated to measure overall system performance.

Test scenarios include:

- Normal verification
- Low lighting
- Blurred document
- Face mismatch
- Spoof attempts

Metrics recorded:

- Verification success rate
- System FAR
- System FRR
- Average verification time

Example table:

| Scenario | Success Rate | Avg Time |
|---------|--------------|----------|
| Normal conditions | 96% | 3.8s |
| Low lighting | 90% | 4.2s |
| Blur scenario | 88% | 4.5s |

---

## 11.6 Hardware Benchmarking

Performance will be measured on representative mobile devices.

Example devices:

- Mid-range Android device
- Flagship Android device

Metrics:

- Latency per module
- End-to-end time
- Memory usage

This demonstrates real-world deployment feasibility.

---

## 11.7 Experiment Reproducibility

To ensure reproducibility:

- All experiments record model version
- Dataset version and seed
- Device type
- Runtime configuration

Experiment scripts will be version-controlled to allow replication.

---

**This completes the full system design, implementation plan, and evaluation framework for the Master's Project.**

