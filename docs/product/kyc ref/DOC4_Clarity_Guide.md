Status: Thesis Canonical

# KYC Thesis — Document 4: Clarity Guide
## What We Are Building, Why, and Every Decision Explained

> This document is for **you**, not your examiner.
> Read this whenever you feel lost about why you are doing something,
> what a metric means, or why a particular approach was chosen or dropped.
> Written in plain language — no academic jargon.

---

# PART 1 — THE BIG PICTURE

## What problem are we actually solving?

When someone signs up for a bank, a fintech app, or any regulated service,
the company is legally required to verify that person is who they say they are.
This is called KYC — Know Your Customer.

Traditionally a human agent looks at your ID and your face.
That is slow, expensive, and doesn't scale.

**We are building an AI system that does this automatically from a mobile phone.**

The user opens the app, scans their ID document, takes a selfie, and the system
decides in under 5 seconds whether they are who they claim to be.

---

## What makes this hard?

Three things make this genuinely difficult:

**1. Bad actors actively try to fool the system.**
Someone might hold up a printed photo of another person's face.
Someone might submit a digitally edited ID document.
Someone might replay a video of a real person to pass the selfie check.
The system must detect all of these attacks.

**2. The models must run on a mobile phone, not a server.**
A face recognition model that works perfectly on a cloud server is useless
if it takes 8 seconds to run on a mid-range Android phone.
We have to shrink the models without losing accuracy.
This size vs accuracy tradeoff is the core research challenge.

**3. Real training data doesn't exist.**
Real KYC datasets contain passport scans, selfies, and ID numbers of real people.
Nobody will give us this data — privacy laws prevent it.
We have to generate fake but realistic training data ourselves.

---

## Why is this a good master's thesis?

Because it covers three genuine AI research problems:

1. **Mobile model compression** — how much can you shrink a neural network
   before its accuracy becomes unacceptable? This is an open research question
   with no single right answer.

2. **Biometric anti-spoofing** — can a model tell the difference between a real
   face and a printed photo or screen replay? This is an active research area.

3. **Probabilistic decision fusion** — you have 5 different AI scores and need
   to combine them into one trust decision. Is a learned model better than
   hand-picked weights? Measuring this is your original contribution.

---

# PART 2 — THE MODELS WE ARE BUILDING

## Model 1 — Document Quality Classifier

### What it does
Looks at a camera frame and answers: is this image good enough to use?

It outputs one of five labels:
- GOOD — proceed with capture
- BLURRY — camera is shaking or out of focus
- GLARE — light is reflecting off the document
- DARK — not enough light
- NO_DOCUMENT — no ID card visible in the frame

### Why we need it
Without this, users would capture a blurry photo of their ID and the OCR
would fail silently. This model runs on every live camera frame and gives
real-time guidance: "hold still", "move to a brighter area", etc.

This is also what makes the app feel professional — it only captures when
the image is actually good. Competitors that skip this step have much higher
verification failure rates.

### What we are training
MobileNetV3-Small pretrained on ImageNet, fine-tuned on synthetic document
images with controlled augmentation applied to create each quality class.

### What "pretrained on ImageNet" means
ImageNet is a dataset of 1.4 million images across 1000 categories (dogs, cars,
buildings, etc). Training on this teaches the model to recognize low-level visual
features: edges, textures, gradients, shapes. We inherit all of this knowledge
and only teach the model the new task (quality classification) on top.
This is called transfer learning. Without it, training from scratch would take
weeks and require millions of document images we don't have.

### What accuracy we expect
92–95% on the validation set. This is good enough — the model runs at 30fps
so occasional wrong frames don't matter. It only needs to be right when the
quality is consistently good for 1.5 seconds.

---

## Model 2 — OCR (We Are NOT Training This)

### What OCR does
Optical Character Recognition — reads text from the document image and extracts
structured fields: name, ID number, date of birth, expiry date.

### Why we use server-side Tesseract (authoritative)
Training a good OCR model requires millions of document images with text
annotations. We don't have this data. Building it from synthetic data alone
produces a model that fails on real printed fonts, handwriting, and special
characters.

For the thesis, we use **server-side Tesseract + MRZ parsing** as the
authoritative OCR path because it is open-source, reproducible, and keeps the
decision pipeline server-authoritative. On-device ML Kit OCR can be used for
**UX pre-fill only** (fast feedback), but it is not trusted for final decisions.

**This is not cutting a corner — it is the correct engineering decision.**
Our thesis contribution is not better OCR. Our contribution is the overall
system, the compression study, and the decision engine.

### What we add on top of OCR
Field extraction logic: OCR gives you raw text. We parse that text to find
the name, ID number, and dates using pattern matching rules. We also score how
confident we are in the extraction — this becomes the `ocr_confidence` signal
fed to the decision engine.

### When does OCR run?
Server OCR runs for all documents as the authoritative source. Optional
on-device OCR can pre-fill fields for UX, but is always re-validated server-side.

---

## Model 3 — Face Embedding Model

### What it does
Takes a face image (112×112 pixels, aligned) and converts it to a list of
128 numbers called an embedding. Think of these 128 numbers as the face's
"fingerprint" — unique to that person.

When we compare two faces, we compare their 128-number embeddings.
If the numbers are close together, the faces are the same person.
If they are far apart, the faces are different people.

### Why 128 numbers?
128 dimensions is enough to capture the key distinguishing features of a face
(jaw shape, eye spacing, nose bridge, etc.) while being small and fast to compare.
Larger embeddings (512 dim) give marginally better accuracy but are much slower.

### The similarity score
We use cosine similarity to compare two embeddings:
- 1.0 = identical face
- 0.0 = completely unrelated faces
- Our threshold: similarity > 0.65 = same person

This threshold is tuned by experiment (the FAR/FRR curve — explained in Part 3).

### Why we are using a pretrained model
MobileFaceNet has been trained by researchers on millions of real face pairs
using a sophisticated loss function (ArcFace). It already knows how to produce
discriminative face embeddings. We download the pretrained weights and use
them directly — we don't need to retrain from scratch.

Training a face embedding model from scratch requires:
- Millions of face images with identity labels
- Weeks of GPU time
- Careful implementation of ArcFace loss

This is a PhD-level undertaking. Using pretrained weights is standard practice
in the industry and in academic KYC papers.

### What we actually do with the face model
1. Extract the face from the ID document photo
2. Extract the face from the selfie
3. Align both faces to the same canonical pose (112×112)
4. Run both through the embedding model
5. Compare the embeddings with cosine similarity
6. The result is `face_similarity` — a number between 0 and 1

---

## Model 4 — Liveness Detection

### What it does
Answers one question: is there a real live person in front of the camera,
or is someone trying to fool the system with a photo or video?

### Why this is hard
A photo of a person's face looks almost identical to a real face from the
camera's perspective. The camera doesn't know if it's looking at a real face
or a printed photo.

### How our model works — passive approach
We use a CNN (convolutional neural network) trained to detect subtle visual
differences between real faces and spoof attacks:

**Print attacks** (holding up a printed photo):
- Paper has a texture — the model learns to detect paper grain patterns
- Photos don't have natural micro-movements
- Lighting falls flat on paper vs. 3D on a real face

**Screen replay attacks** (holding another phone showing a video):
- Screens produce a Moiré pattern — a subtle grid artifact visible to cameras
- Screen pixels have a different texture than real skin
- Screen brightness is uniform vs. natural face lighting

**Video replay attacks** (replaying a recorded video):
- Similar to screen replay but often higher quality
- Lack of blink randomness and natural micro-movements

### Why we chose single-frame passive (not the hybrid two-branch temporal model)
The original spec described a complex hybrid model: a passive CNN for texture
plus a temporal CNN that analyses motion across multiple video frames.

We dropped the temporal branch because:
- (2+1)D temporal convolutions are complex to implement and debug
- Training on video sequences requires much more GPU time
- The accuracy gain is marginal on standard benchmarks
- A single-frame passive CNN fine-tuned on CelebA-Spoof gives a practical thesis baseline with publishable error rates

Instead, we add active liveness through the Flutter app for UX guidance:
- Ask the user to blink
- Ask the user to turn their head left then right
- Google ML Kit Face Detection detects whether the user complied

This hybrid passive (CNN model) + active (ML Kit challenge) approach is
simpler to implement, but only the passive model is authoritative.

### The dataset
CelebA-Spoof is the canonical thesis baseline dataset for liveness.
It contains large-scale spoof and live samples with rich annotations and is the
official baseline used for training and primary reporting in this project.
OULU-NPU and CASIA-FASD are optional supplementary benchmarks when available.

---

## Model 5 — Decision Engine

### What it does
Takes all the scores from the other models and produces one final answer:
ACCEPT, REJECT, or MANUAL REVIEW.

Inputs:
- `face_similarity` — how closely does the selfie match the ID photo?
- `liveness_score` — is the selfie from a real live person?
- `ocr_confidence` — how clearly could we read the document text?
- `doc_quality_score` — was the document image good quality?
- `field_valid_score` — do the extracted fields pass validation rules?

Output: a probability between 0 and 1 that the user is genuine.

### Why this is a research contribution
The naive approach is to manually assign weights:
face_similarity × 0.40 + liveness × 0.30 + ... = risk score

This is what most KYC papers do. The problem: how do you know 0.40 is the
right weight for face similarity? What if liveness is actually more important?
What if a high liveness score combined with a low face similarity should
trigger rejection even if all other scores are fine?

We compare three approaches:

**Approach 1: Fixed weights (baseline)**
Manual weights based on intuition. This is the strawman we beat.

**Approach 2: Logistic Regression (proposed)**
A simple machine learning model trained on labeled verification session data.
It learns the optimal weights from data instead of guessing them.
It also naturally produces calibrated probabilities — important for the
manual review threshold.

**Approach 3: XGBoost with isotonic calibration (proposed)**
A gradient boosted tree model that captures non-linear relationships between
signals. For example: a face_similarity of 0.60 combined with a liveness_score
of 0.40 should be treated differently than both being 0.50. XGBoost learns
these interactions automatically.

**Why this matters for the thesis:** measuring which approach gives better
calibrated probabilities (lower ECE, lower Brier score) is a clean, original
experiment. The result, whichever wins, is a genuine finding.

---

# PART 3 — THE METRICS WE ARE MEASURING

## Why metrics matter more than the model

In AI, a model is only as good as how you measure it. Using the wrong metric
can make a bad model look good. This section explains every metric used in
the thesis and why it was chosen.

---

## Metric Group 1 — Face Verification Metrics

### FAR — False Acceptance Rate
**Plain language:** How often does the system let an impostor through?

Formula: (impostors accepted) / (total impostor attempts)

Example: if 100 different people try to impersonate someone and 3 get through,
FAR = 0.03 = 3%.

For a KYC system, a high FAR means fraudsters can create accounts using
stolen identities. This is the most dangerous error.

### FRR — False Rejection Rate
**Plain language:** How often does the system wrongly reject a real user?

Formula: (genuine users rejected) / (total genuine attempts)

Example: if 100 real users try to verify and 5 are rejected, FRR = 0.05 = 5%.

A high FRR means real customers can't pass verification — bad for user experience
and startup revenue.

### The FAR/FRR Tradeoff
FAR and FRR always trade off against each other. If you lower the similarity
threshold (accept more people), FAR goes up and FRR goes down. If you raise
the threshold (be stricter), FAR goes down and FRR goes up.

**This tradeoff is your threshold tuning experiment.** You sweep thresholds from
0.40 to 0.90, measure FAR and FRR at each threshold, and plot the ROC curve.
The operating point you choose depends on the application:
- A bank wants very low FAR (don't let fraudsters in)
- A simple age verification app might tolerate higher FAR for lower FRR

### EER — Equal Error Rate
The threshold where FAR = FRR. Used as a single number to compare models.
Lower EER = better model. Expected: 2–5% with pretrained MobileFaceNet.

### ROC Curve — Receiver Operating Characteristic
A plot of True Positive Rate vs False Positive Rate across all thresholds.
The Area Under the Curve (AUC-ROC) summarises the whole curve in one number.
AUC = 1.0 is perfect. AUC = 0.5 is random guessing.

---

## Metric Group 2 — Liveness Detection Metrics

These are the ISO/IEC 30107-3 standard metrics for anti-spoofing evaluation.
Using ISO standard metrics makes your results comparable to every published
liveness paper.

### APCER — Attack Presentation Classification Error Rate
**Plain language:** How often does the model think a fake face is real?

Formula: (spoof attacks classified as live) / (total spoof attacks)

Low APCER = system is good at catching fake faces.
Example: APCER = 0.05 means 5% of spoof attacks are wrongly accepted.

### BPCER — Bona Fide Presentation Classification Error Rate
**Plain language:** How often does the model think a real face is fake?

Formula: (genuine faces classified as spoof) / (total genuine faces)

Low BPCER = system doesn't wrongly reject real users.
Example: BPCER = 0.03 means 3% of real users are rejected as potential spoofs.

### ACER — Average Classification Error Rate
Formula: (APCER + BPCER) / 2

This is the headline metric for liveness — one number that balances both
error types. Lower is better. Target: ACER < 0.10 (10%).

With a MobileNetV2 fine-tune on CelebA-Spoof, ACER in the low double-digit
range can still be acceptable for a master's thesis baseline, provided the
limitations and domain-gap implications are reported transparently.

---

## Metric Group 3 — OCR Metrics

### CER — Character Error Rate
**Plain language:** What percentage of characters did the OCR get wrong?

Formula: (substitutions + insertions + deletions) / total characters

Example: "John Smith" read as "Jonn Snith" = 2 wrong out of 10 = CER 0.20

We use this to evaluate server-side Tesseract OCR. If optional on-device OCR
is enabled for UX, we can compare its accuracy to the server results.

### Field Accuracy
**Plain language:** What percentage of the key fields were extracted correctly?

A field is "correct" if it exactly matches the ground truth label.
We measure name accuracy, ID number accuracy, DOB accuracy, expiry accuracy
separately because each has different difficulty.

---

## Metric Group 4 — Model Compression Metrics

These four metrics together tell the full story of whether compression worked.

### Model Size (MB)
The size of the model file on disk.
This matters because: the TFLite files are bundled inside the mobile app.
App stores have size limits. Users don't want to download a 500MB app.
Target: all four models combined under 50MB.

### Inference Latency (ms)
How long it takes to run the model once on a mobile CPU.
This is measured on a real Android device (not an emulator, not a GPU server).

Targets:
- Quality model: under 20ms (runs on every frame)
- Face embedding: under 150ms
- Liveness: under 200ms
- End-to-end total: under 5 seconds

### Peak Memory Usage (MB)
How much RAM the model needs during inference.
Mobile phones have limited RAM. If the model needs 2GB, it will crash on
most phones. We measure this to prove the system is deployable on mid-range devices.

### Accuracy After Compression
After compressing the model (making it smaller and faster), how much accuracy
did we lose? This is the most important number — there is no point in a fast
model that no longer works.

We express this as delta from baseline:
"INT8 quantization reduced accuracy by 1.2 percentage points while achieving
4× size reduction and 2.3× latency improvement."
That sentence is a result that belongs in a thesis.

---

## Metric Group 5 — Decision Engine Metrics

### AUC-ROC
Already explained above. Applied here to the decision engine's ability to
separate genuine users from fraudsters. Higher = better.

### Brier Score
**Plain language:** How accurate are the probability estimates?

If the model says "70% chance this is genuine" for 100 users, about 70 of
them should actually be genuine. If the model consistently says 70% but only
50 are genuine, the probabilities are not calibrated — they are misleading.

Brier Score measures this calibration. Range 0 to 1. Lower = better.
A perfect model has Brier score 0. Random guessing gives 0.25.

### ECE — Expected Calibration Error
Another calibration metric. Plots what the model said (predicted probability)
vs what actually happened (true frequency). A perfectly calibrated model's
line is a straight diagonal. ECE measures how far off the model is.

**Why calibration matters for your startup:** businesses paying for KYC make
decisions based on the risk score. If the score says 0.8 probability of genuine
but that number is not calibrated, the manual review threshold becomes meaningless.
A calibrated decision engine is a product feature, not just an academic metric.

---

## Metric Group 6 — Fairness Metrics

### Subgroup FAR and FRR
We compute FAR and FRR separately for demographic subgroups (age groups,
gender, skin tone using the Fitzpatrick scale).

If the system has FAR = 2% overall but FAR = 8% for one demographic group,
that group is 4x more likely to have impostors accepted. This is a serious
fairness problem that would also be a legal liability for the startup.

### Max Disparity
The maximum difference in FAR (or FRR) between any two groups.
This is the headline fairness number. Lower = fairer system.

### Why this is in the thesis
Any AI system deployed in financial services is subject to fairness scrutiny.
Your examiner will ask about this. More importantly, as a startup you cannot
sell to regulated businesses if your system discriminates.

---

# PART 4 — THE OPTIMIZATION STUDY EXPLAINED

## What "optimization" means in this context

We are not optimising the model's accuracy by training it better.
We are taking a trained model and making it smaller and faster while
trying to keep accuracy as close to the original as possible.

This is called model compression. It is a distinct field from model training.

---

## Why we need to compress models at all

A typical face recognition model trained for maximum accuracy:
- Size: 100–500MB
- Inference time on mobile CPU: 2–10 seconds
- RAM usage: 500MB+

These numbers are completely unacceptable for a mobile app.
The models must be small enough to ship in an app and fast enough to feel instant.

---

## Technique 1 — Post-Training Quantization (PTQ)

### What it is
A trained model stores its numbers (weights) as 32-bit floating point values
(FP32). Each weight takes 4 bytes of memory.

Quantization converts these to 8-bit integers (INT8). Each weight takes 1 byte.

Result: the model is 4× smaller immediately. No retraining required.
Mobile CPUs also run INT8 operations faster than FP32.

### Why accuracy might drop
INT8 can represent 256 different values. FP32 can represent 4 billion different
values. Rounding the precise FP32 weights to the nearest INT8 value introduces
small errors. For some models these errors are negligible. For some (especially
face embedding) they can matter.

### When to use it
Always try PTQ first. It is the fastest win: 3 lines of code, no retraining,
usually < 2% accuracy drop.

### What we measure
- Before PTQ: model size, latency, accuracy
- After PTQ: model size, latency, accuracy
- Report: size reduction ratio, latency speedup, accuracy delta

---

## Technique 2 — Knowledge Distillation

### What it is
You have a large accurate model (the teacher).
You train a smaller model (the student) to imitate the teacher.

The student doesn't just learn from the correct labels (e.g. "this is a real
face"). It also learns from the teacher's output probabilities (e.g. "the
teacher was 87% confident this was real and 13% it was spoof"). These soft
probability outputs contain more information than hard labels.

The student learns a richer representation than it would from labels alone.
Result: the small student model gets much closer to the teacher's accuracy
than it would if trained independently.

### Why this is better than just training a small model
If you train MobileNetV2-050 (half the channels) directly from scratch, it
learns less because it has seen less. If you distil from MobileNetV2-100
(full size), the small model learns what the big model "knows" — giving it
accuracy closer to the bigger model in a smaller architecture.

### What we measure
- Teacher model: accuracy (this is the ceiling)
- Student without distillation: accuracy
- Student with distillation: accuracy
- The gap closed by distillation = your research finding

---

## Why We Only Do PTQ + Distillation (Not QAT or Pruning)

The original spec listed 5 compression techniques. We kept 2.

**Quantization-Aware Training (QAT) — dropped**
QAT retrains the model with fake quantization nodes so it learns to be robust
to INT8 precision loss. It recovers accuracy that PTQ loses.
We dropped it because: if PTQ accuracy drop is < 2%, QAT adds weeks of
training for marginal gain. We will try PTQ first. If accuracy drop is large
on a specific model, we can add QAT for that model only.

**Structured Pruning — dropped**
Pruning removes entire filters/channels from the model, making it structurally
smaller. This is powerful but requires a careful iterative training loop:
prune → fine-tune → evaluate → repeat. Complex to implement correctly.
The accuracy recovery from distillation is simpler to implement and gives
comparable results for our model sizes.

**This is not a weakness — it is a focused thesis.**
Doing 2 techniques rigorously and measuring them carefully is better than
doing 5 techniques superficially. Your examiner would rather see clean,
reproducible results on PTQ + distillation than noisy results across 5 methods.

---

# PART 5 — WHAT WE REMOVED AND WHY

## Removed: Donut Model

### What it was
Donut (Document Understanding Transformer) is a transformer model that takes
a full document image and outputs structured JSON directly. No OCR engine needed.

### Why it sounded good
End-to-end, no template rules, generalises to unseen document layouts.

### Why we removed it
- Model size: 200MB+. Cannot run on mobile at all — server only.
- Training time: 24–48 hours fine-tuning. High risk of Colab timeouts.
- Adds 2–3 weeks of work for a component that Tesseract already handles well.
- We would have two OCR systems doing the same job.

### What we use instead
Server-side Tesseract + MRZ parsing (authoritative), with optional on-device
ML Kit OCR for UX pre-fill only. This keeps the thesis pipeline reproducible.

---

## Removed: DANN (Domain Adversarial Neural Network)

### What it was
A technique for closing the domain gap between synthetic training data
(our generated ID images) and real documents. DANN adds a second classifier
branch that tries to tell synthetic from real images, and the main model
is trained to fool it — forcing it to learn domain-invariant features.

### Why it sounded good
It directly addresses the synthetic-to-real domain gap problem.

### Why we removed it
- DANN is notoriously difficult to train stably. The adversarial training
  loop often diverges or the two branches don't converge together.
- Debugging DANN failures requires deep understanding of adversarial training.
- High risk of spending 2 weeks with no result.

### What we do instead
We explicitly measure and report the synthetic-to-real domain gap in the
evaluation section (Section 10.4 in the spec). Train on synthetic data,
test on a small set of real documents, report the accuracy drop honestly.
This is more academically honest than pretending DANN always works.

---

## Removed: Test-Time Adaptation (TTT)

### What it was
A technique where at inference time, the model briefly fine-tunes itself
on the new input before making a prediction.

### Why it sounded good
Helps the model generalise to document types it has never seen before.

### Why we removed it
- Very experimental — limited published success on production systems.
- Adds latency at inference time (fine-tuning takes time).
- Unpredictable: if it doesn't work, you have no fallback and no result.
- For a thesis with a fixed deadline, "promising but didn't work" is not
  an acceptable outcome.

### What we do instead
Mentioned in Future Work as a natural next step for the research.

---

## Removed: The Hybrid Two-Branch Liveness Model

### What it was
A liveness detector with two separate model branches:
1. A passive branch (CNN on single frames — texture analysis)
2. An active branch (3D CNN on video sequences — motion analysis)
Both branches trained jointly, fusion weights learned.

### Why it sounded good
More robust than single-frame — temporal motion adds extra signal.
Combining passive texture detection with active motion analysis is more
resistant to high-quality video replay attacks.

### Why we removed it
- (2+1)D convolutions (factorised 3D convs) are complex to implement correctly.
  Getting the tensor dimensions right for video sequences in PyTorch is tricky.
- Training on video requires significantly more GPU time and more complex
  data loading (loading N frames per sample instead of 1 image).
- The accuracy improvement on standard benchmarks is 3–8% ACER — meaningful
  but not enough to justify the implementation complexity for a thesis.

### What we do instead
Single-frame passive CNN (MobileNetV2 fine-tuned on CelebA-Spoof) for the model.
Active liveness via Flutter app: ML Kit detects blink and head turn challenges
for UX guidance only (not used in the authoritative decision).

---

## Removed: 5 Compression Variants (Kept 3)

### What we dropped
- QAT (Quantization-Aware Training) — see explanation above
- Structured Pruning — see explanation above

### What we kept
- FP32 Baseline
- INT8 Post-Training Quantization
- Knowledge Distillation

### Why 3 is enough
3 variants × 3 models (quality, face, liveness) = 9 experiments.
9 experiments with clean results is a full thesis chapter.
Adding 2 more techniques gives 5 × 3 = 15 experiments with more noise,
more debugging, and diminishing returns on the research contribution.

---

# PART 6 — THE STARTUP ANGLE

## How the thesis work maps to the startup

| Thesis Component | Startup Value |
|---|---|
| Server-authoritative hybrid | Security and compliance-friendly |
| On-device quality UX | Faster capture, fewer failed uploads |
| Server OCR (Tesseract) | Predictable cost, reproducible results |
| Compression study | Proven low-cost server inference |
| Decision engine calibration | Tunable thresholds for different client risk tolerances |
| Django admin | Manual review console — ready from day one |
| API key auth | Billing gate — per-verification pricing built in |
| Fairness evaluation | Required for regulated financial clients |

## The cost per verification argument
Your startup's pricing pitch:
- Jumio/Onfido charge $1–5 per verification
- Your system runs capture guidance on-device; inference runs on server
- Server costs: OCR + face + liveness + decision engine + storage
- Estimated server cost per verification: $0.04–0.10
- You can charge $0.20–0.50 and still massively undercut the market

This calculation belongs in your thesis conclusion AND your startup pitch deck.

---

# PART 7 — QUICK REFERENCE

## If you forget what a metric means

| Metric | Measures | Better = |
|---|---|---|
| FAR | How often impostors pass | Lower |
| FRR | How often real users are rejected | Lower |
| EER | Balance point of FAR and FRR | Lower |
| AUC-ROC | Overall discrimination ability | Higher |
| APCER | Spoof attacks that fool liveness | Lower |
| BPCER | Real users rejected by liveness | Lower |
| ACER | Overall liveness error | Lower |
| CER | OCR character accuracy | Lower |
| Field Accuracy | OCR field extraction accuracy | Higher |
| Model Size (MB) | Storage footprint | Lower |
| Latency (ms) | Inference speed | Lower |
| Brier Score | Probability calibration | Lower |
| ECE | Calibration error | Lower |
| Subgroup FAR/FRR | Fairness across demographics | Lower disparity |

## If you forget why we use each model

| Model | Why This Architecture |
|---|---|
| MobileNetV3-Small (quality) | Fastest MobileNet variant — must run at 30fps |
| Tesseract + MRZ (server) | Reproducible OCR, consistent with server-authoritative decisions |
| MobileFaceNet pretrained | Best face embedder in the mobile size range |
| MobileNetV2 (liveness) | Good accuracy, stable training, well-documented |
| Logistic Regression (decision) | Interpretable, calibrated, fast, provably better than fixed weights |
| XGBoost (decision) | Captures signal interactions, best AUC expected |

## If you forget what each build document contains

| Document | Contents |
|---|---|
| DOC1 — AI Training | How to train all models, export to ONNX (server) + TFLite (quality only) |
| DOC2 — Backend | Django project, all API endpoints, ML model loading pattern |
| DOC3 — Flutter | Full app screens, TFLite inference in Dart, API calls |
| DOC4 — This doc | Why everything was decided, all metrics explained |
| Master Spec | Formal academic thesis specification |

---

*This document will make more sense as you progress through the build.
Re-read the relevant section whenever you feel uncertain about a decision.*
