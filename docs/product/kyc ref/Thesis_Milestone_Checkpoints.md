# Thesis Milestone Checkpoints
## KYC AI Verification System — Master's Thesis Progress Tracker

**How to use this document:**
Come back to this document at the end of every milestone.
Read the criteria. Answer honestly. Follow the path it gives you.
Bring it to every session with Claude so we start from the right place.

---

## Implementation Readiness Checklist (Before Flutter)

Use this short checklist to confirm the pipeline is stable before building the Flutter app.

- [ ] Architecture decision locked: server-authoritative inference, mobile UX only
- [ ] Backend API contract is final: `start → upload → poll`
- [ ] OCR pipeline works server-side (Tesseract + MRZ parsing)
- [ ] Face embedding model runs in ONNX Runtime on the server
- [ ] Liveness model runs in ONNX Runtime on the server
- [ ] Decision engine returns consistent risk scores and reason codes
- [ ] End-to-end backend flow runs on sample images (no mobile yet)

If any item is unchecked, fix it before starting Flutter to avoid rework.

---

## API Contract Summary (Backend)

```
POST /api/v1/verify/start/    → { session_token, expires_in }
POST /api/v1/verify/upload/   → { session_id, estimated_wait_ms }
GET  /api/v1/verify/{id}/     → { decision, risk_score, reason_codes, timestamp }
```

This is the only mobile ↔ backend contract used in the thesis prototype.

---

## Flutter Task Checklist (Milestone-Based)

Use this as a complete build checklist so nothing is missed. Check off in order.

---

### Milestone F1 — Project Setup & Permissions
- [ ] Create Flutter project structure (per DOC3)
- [ ] Add dependencies (camera, mlkit, dio, tflite_flutter, riverpod, etc.)
- [ ] Android permissions set (CAMERA, INTERNET)
- [ ] iOS permissions set (NSCameraUsageDescription)
- [ ] Basic routing wired (home → document → selfie → processing → result)
- [ ] Build runs on a physical Android device

---

### Milestone F2 — Camera + Document Capture UX
- [ ] Camera preview renders reliably
- [ ] Document frame overlay drawn (ID card aspect ratio)
- [ ] ML Kit boundary detection integrated
- [ ] Perspective warp applied to document image
- [ ] Auto-capture when quality is GOOD for 1.5s
- [ ] Encrypted document image saved locally

---

### Milestone F3 — On-Device Quality Feedback (UX Only)
- [ ] TFLite doc_quality model loads at startup
- [ ] Frame skipping implemented (every 3rd frame)
- [ ] Real-time quality label + message displayed
- [ ] Edge cases handled (no document, glare, dark)

---

### Milestone F4 — Selfie + Active Liveness UX
- [ ] Front camera selfie preview works
- [ ] ML Kit face detection integrated
- [ ] Blink + head-turn challenge prompts show correctly
- [ ] Challenge completion tracked (UX only)
- [ ] Best selfie frame captured and encrypted

---

### Milestone F5 — Backend API Integration (Authoritative)
- [ ] `/verify/start/` called successfully
- [ ] `/verify/upload/` sends document + selfie images
- [ ] `/verify/{session_id}/` polled until decision
- [ ] Errors surfaced to user with retry path

---

### Milestone F6 — Result Screen + Reason Codes
- [ ] Result screen shows ACCEPT / REJECT / MANUAL_REVIEW
- [ ] Risk score displayed (optional, thesis demo)
- [ ] Reason codes rendered as chips
- [ ] “Done” returns to home

---

### Milestone F7 — Reliability & Polish
- [ ] Handles permission denial gracefully
- [ ] Handles network loss (retry + timeout)
- [ ] Ensures no UI jank (move heavy work off UI thread)
- [ ] App survives background/foreground transitions
- [ ] Basic analytics/logging for failures

---

## Flutter Daily Sprint Plan (Suggested)

Short, focused daily goals to keep momentum and avoid rework.

### Day 1 — F1 Setup
- Project scaffold + dependencies
- Permissions + routing
- Run on physical device

### Day 2 — F2 Camera + Document Capture
- Camera preview + overlay
- Boundary detection + warp
- Auto-capture flow

### Day 3 — F3 Quality Feedback
- TFLite model loading
- Frame skipping + live feedback
- Edge cases (no doc, glare, dark)

### Day 4 — F4 Selfie + Liveness UX
- Front camera + face detection
- Blink/head-turn prompts
- Best frame capture

### Day 5 — F5 Backend Integration
- start → upload → poll flow
- Error + retry handling

### Day 6 — F6 Result Screen
- Decision UI + reason codes
- Risk score (optional)
- Done → Home

### Day 7 — F7 Polish + Stabilization
- Background/foreground handling
- Performance fixes
- Final QA on device


## BEFORE YOU START ANYTHING
### Readiness Check

Answer these before writing a single line of code:

- [ ] Google Colab account created, T4 GPU confirmed working
- [ ] Google Drive mounted and test checkpoint saved successfully
- [ ] CelebA-Spoof download started (5GB — start it now, it takes time)
- [ ] CASIA-FASD registration submitted
- [ ] OULU-NPU application submitted (10 minutes — do it now)
- [ ] Physical Android device available for Flutter testing
- [ ] Supervisor meeting booked to confirm thesis direction
- [ ] Thesis submission deadline confirmed: _______________

**If any of these are not done — do them before starting Milestone 1.**
They will block you later at the worst possible time.

---

---

# MILESTONE 1
## Document Quality Classifier
### Target completion: End of Week 2

---

### What you are building
- Synthetic dataset generated (1,000+ images per class, 5 classes)
- MobileNetV3-Small trained, val accuracy tracked per epoch
- Test set evaluated — classification report + confusion matrix saved
- Compression study: FP32 baseline + INT8 PTQ + Distilled student
- Results table produced (size, latency, accuracy for all 3 variants)
- TFLite export: doc_quality.tflite saved to Google Drive

---

### Criteria — Did it work?

**Green — Achieved**
- Test accuracy ≥ 88% on synthetic test set
- INT8 PTQ accuracy drop ≤ 3 percentage points vs FP32
- TFLite file exports cleanly and passes interpreter validation
- Confusion matrix shows clear diagonal (most mistakes are between adjacent classes e.g. BLURRY/DARK, not GOOD/NO_DOCUMENT)

**Yellow — Partial, continue with caution**
- Test accuracy 75–87%
- PTQ drop > 3pp but < 8pp
- TFLite export works but model size > 8MB
- Some class confusion between GOOD and BLURRY

**Red — Something is wrong, stop and diagnose**
- Test accuracy < 75% after 30 epochs
- Model not converging (loss not decreasing after epoch 5)
- TFLite export fails completely
- All predictions collapsing to one class

---

### What to say in your thesis if Green
> "The document quality classifier achieved [X]% test accuracy on the
> synthetic evaluation set across five quality classes. INT8 post-training
> quantisation reduced model size by [X]× with an accuracy delta of [X]pp,
> demonstrating that compressed models are viable for on-device pre-screening.
> The confusion matrix reveals expected near-boundary confusion between
> BLURRY and DARK classes, consistent with the overlapping visual features
> of these degradation types."

---

### What to say in your thesis if Yellow
> "The document quality classifier achieved [X]% test accuracy. While below
> the 90% target, analysis of the confusion matrix indicates that
> misclassifications are concentrated at class boundaries (BLURRY/DARK),
> where the distinction is inherently ambiguous even to human annotators.
> For the deployment use case — rejecting clearly poor quality captures
> before upload — the model's performance on the GOOD vs non-GOOD binary
> distinction was [X]%, which is sufficient for the pre-screening role."

---

### What to do if Red
1. Check if GPU was enabled in Colab (most common cause)
2. Visualise 10 samples per class — are the augmentations too aggressive?
3. Reduce N_PER_CLASS to 200, run 5 epochs — does loss decrease at all?
4. If loss decreases on small dataset → data loading issue on full dataset
5. If loss never decreases → learning rate too high, try 1e-5
6. Come back to Claude with: training loss curve screenshot + confusion matrix

---

### Checkpoint questions to answer before moving to Milestone 2
- What was my final test accuracy? ____%
- What was my INT8 accuracy drop? ____pp
- What is the TFLite file size? ____MB
- Did the export work? Yes / No / Partially
- What was the hardest problem I hit and how did I solve it?

---

---

# MILESTONE 2
## Face Embedding Model
### Target completion: End of Week 4

---

### What you are building
- MobileFaceNet pretrained weights loaded from facenet-pytorch
- Evaluated on LFW dataset — FAR/FRR curve plotted, EER calculated
- Compression study: FP32 + INT8 PTQ variants benchmarked
- ONNX export: face_embedder.onnx saved
- TFLite export attempted: face_embedder.tflite (may be harder than quality model)

---

### Criteria — Did it work?

**Green — Achieved**
- EER on LFW ≤ 5%
- INT8 PTQ accuracy drop ≤ 5pp (face embedding is more sensitive to quantisation)
- ONNX export works and passes inference check
- TFLite export works

**Yellow — Partial, continue with caution**
- EER 5–10% on LFW
- PTQ drop > 5pp (document this — it is a thesis finding, not a failure)
- ONNX works but TFLite export fails
- Latency higher than target but model produces valid embeddings

**Red — Something is wrong**
- EER > 20% (worse than random for face verification)
- Model produces identical embeddings for all inputs
- ONNX export fails completely

---

### What to say in your thesis if Green
> "Face embedding evaluation on LFW achieved EER [X]%, within the target
> range of 2–5%. The face similarity component demonstrates that
> MobileFaceNet pretrained on VGGFace2 generalises to the verification
> task without domain-specific fine-tuning. INT8 quantisation produced
> an EER increase of [X]pp — higher sensitivity than the quality classifier,
> consistent with the known fragility of embedding models to reduced
> numerical precision."

---

### What to say in your thesis if Yellow (PTQ drop > 5pp)
> "INT8 post-training quantisation of the face embedding model produced
> an EER increase of [X]pp, exceeding the threshold observed in the
> quality classifier ([X]pp). This asymmetry confirms the known result
> that embedding models are more sensitive to quantisation than
> classification models, as small perturbations in embedding space
> affect similarity thresholds proportionally. This finding motivates
> the use of FP32 or distilled models for face embedding in
> deployment, reserving INT8 quantisation for the quality and
> liveness classifiers."

---

### What to do if Red
1. Verify LFW pairs file is loaded correctly — print first 5 pairs and labels
2. Check embedding norms — should all be ~1.0 (L2 normalised)
3. Verify cosine similarity range — should span -1 to +1 across pairs
4. If all embeddings identical → model weights not loaded correctly
5. Come back to Claude with: sample embedding values + similarity histogram

---

### Checkpoint questions
- EER on LFW? ____%
- INT8 PTQ EER increase? ____pp
- Did ONNX export work? Yes / No
- Did TFLite export work? Yes / No / Partially
- Biggest surprise finding from this milestone?

---

---

# MILESTONE 3
## Liveness Detection Model
### Target completion: End of Week 7

> ⚠️ This is your highest risk milestone. Budget 3 weeks not 1.
> Start CelebA-Spoof preprocessing in Week 4 while still finishing
> face embedding — do not wait.

---

### What you are building
- CelebA-Spoof dataset preprocessed and split
- MobileNetV2 fine-tuned for binary live/spoof classification
- APCER, BPCER, ACER calculated on CASIA-FASD test set
- ROC curve plotted and saved
- If OULU-NPU access arrived — additional evaluation on Protocol 1 and 2
- Compression study: FP32 + INT8 + Distilled variants
- ONNX export: liveness.onnx saved

---

### Criteria — Did it work?

**Green — Achieved**
- ACER ≤ 12% on CASIA-FASD
- INT8 ACER increase ≤ 5pp
- ONNX export works
- Training converged (loss curve shows clear decrease)

**Yellow — Partial, continue with caution**
- ACER 12–20% on CASIA-FASD
- Model shows clear learning (better than random 50%) but not hitting target
- INT8 drop > 5pp
- TFLite export fails but ONNX works

**Red — Something is wrong**
- ACER > 40% (near random)
- Loss not converging after 10 epochs
- BPCER > 50% (system rejecting most real users)

---

### What to say if Green
> "Liveness detection trained on CelebA-Spoof achieved ACER [X]% on
> CASIA-FASD, within the target range for a mobile-optimised passive
> liveness detector. APCER of [X]% and BPCER of [X]% indicate the
> model's operating point balances attack resistance against user
> experience. Combined with active challenge-response via ML Kit,
> the fused liveness system provides layered protection appropriate
> for the fintech onboarding threat model."

---

### What to say if Yellow (ACER 12–20%)
> "Liveness detection achieved ACER [X]% on CASIA-FASD. While above
> the target of 12%, this result reflects the domain gap between
> CelebA-Spoof training data and CASIA-FASD test conditions —
> a known challenge in anti-spoofing research where cross-dataset
> generalisation typically degrades performance by 5–15pp. The active
> challenge-response component (blink + head turn via ML Kit) provides
> a complementary security layer that compensates for passive model
> limitations, consistent with the hybrid approach used in
> production KYC systems."

---

### What to do if Red
1. Check class balance — print spoof vs live counts in training split
2. Verify augmentation is not destroying spoof texture cues
3. Try training on CASIA-FASD only (smaller, cleaner) for first 5 epochs
4. Check learning rate — liveness is more sensitive, try 5e-5
5. Come back to Claude with: loss curve + APCER/BPCER breakdown by attack type

---

### Checkpoint questions
- ACER on CASIA-FASD? ____%
- APCER? ____% BPCER? ____%
- Did OULU-NPU access arrive? Yes / No
- If yes — ACER on OULU-NPU Protocol 1? ____%
- INT8 ACER increase? ____pp
- Did ONNX export work? Yes / No
- Weeks spent on this milestone: ____

---

---

# MILESTONE 4
## Compression Study — Full Results Table
### Target completion: End of Week 9

---

### What you are building
- All 9 experiments complete:
  Quality (FP32 / INT8 / Distilled)
  Face Embedding (FP32 / INT8 / Distilled)
  Liveness (FP32 / INT8 / Distilled)
- Results table: model, variant, size(MB), latency(ms), accuracy metric
- Bar charts saved for thesis figures
- Key finding identified and written up

---

### Criteria — Did it work?

**Green — All 9 experiments complete**
- Full 9-row results table produced
- At least one interesting finding (e.g. face embedding more sensitive to
  INT8 than quality classifier — expected result)
- All charts saved

**Yellow — 6–8 experiments complete**
- One model's distillation failed or one export broke
- 6 or 7 rows in results table
- Still publishable with honest explanation of what was skipped and why

**Red — Fewer than 6 experiments**
- Multiple failures across models
- Results table too sparse to support compression study claims

---

### What to say if Yellow (partial results)
> "The compression study was completed for [X] of 9 planned experiments.
> [Model name] distillation was not completed within the thesis timeline
> due to [specific reason]. Results for the completed experiments are
> presented in Table X. The partial results are sufficient to support
> the primary finding: INT8 quantisation sensitivity varies significantly
> across model types, with embedding models showing greater accuracy
> degradation than classification models under the same quantisation scheme."

---

### Checkpoint questions
- How many of 9 experiments completed? ____
- Which variant showed the biggest size reduction? ____________
- Which model was most sensitive to INT8? ____________
- What is the single most important finding from this table?
- Are charts saved and thesis-ready? Yes / No

---

---

# MILESTONE 5
## Decision Engine
### Target completion: End of Week 10

---

### What you are building
- Simulated session dataset generated (1,000+ sessions)
- Three variants compared: fixed weights vs logistic regression vs XGBoost
- AUC-ROC, Brier Score, ECE calculated for each
- Calibration curves plotted
- Best model selected with justification
- decision_engine.pkl saved

---

### Criteria — Did it work?

**Green — Achieved**
- XGBoost or logistic regression clearly outperforms fixed weights on AUC-ROC
- Brier Score and ECE show meaningful calibration difference between variants
- Results table clean and interpretable

**Yellow — Partial**
- All three variants perform similarly (small differences)
- Calibration differences not dramatic

**Red — Something wrong**
- All models perform at random (AUC ~0.5)
- Simulated data generation has a bug

---

### What to say if Yellow (small differences)
> "The decision engine comparison revealed modest performance differences
> between the three variants (AUC-ROC range: [X]–[X]%). The similarity
> in discrimination performance reflects the high information content of
> the five input signals — when biometric scores are strong, any
> reasonable aggregation method produces correct decisions. The more
> meaningful differences were in calibration: XGBoost with isotonic
> calibration achieved ECE [X]% vs [X]% for the fixed weights baseline,
> indicating better probability estimates even when rank ordering is
> similar. Well-calibrated risk scores are critical for the manual
> review routing threshold, making calibration the primary selection
> criterion."

---

### Checkpoint questions
- Best model AUC-ROC? ____
- Fixed weights AUC-ROC? ____
- Brier Score improvement over baseline? ____
- Which model was selected and why in one sentence?

---

---

# MILESTONE 6
## Django Backend
### Target completion: End of Week 13

---

### What you are building
- All API endpoints working and tested with Postman or curl
- ONNX Runtime inference running server-side for all three models
- Decision engine integrated
- Celery task queue processing verification sessions
- Django admin manual review console working
- Docker-compose running locally (db + redis + backend + celery)
- Basic API key authentication working

---

### Criteria — Did it work?

**Green — Achieved**
- POST /verify/upload/ accepted and GET /verify/{session_id}/ returns a decision in < 5 seconds
- Django admin shows sessions with risk scores and decision
- Manual approve/reject works in admin
- Docker-compose up brings everything up cleanly

**Yellow — Partial**
- API works but Celery not integrated — inference runs synchronously
- Admin console works but some fields missing
- Docker-compose works but requires manual steps

**Red — Blocked**
- ONNX Runtime failing to load models
- API returning errors on every request
- Database migrations broken

---

### What to say if Yellow (synchronous inference)
> "The backend API implements the full verification pipeline including
> server-side biometric inference via ONNX Runtime. Asynchronous task
> processing via Celery is implemented and functional; however, due to
> time constraints the production deployment uses synchronous inference
> for the research prototype. Asynchronous processing is designated as
> a production hardening step that does not affect the validity of the
> experimental results."

---

### Checkpoint questions
- Average API response time for /verify/{session_id}/? ____ms
- Does admin console show risk scores? Yes / No
- Is Docker-compose working? Yes / No / Partially
- Biggest unexpected problem in backend development?

---

---

# MILESTONE 7
## Flutter App
### Target completion: End of Week 17

> ⚠️ This is your highest integration risk milestone.
> You need a physical Android device.
> Build with mock scores first — wire real models last.

---

### What you are building
- Document capture screen with real-time quality feedback
- Selfie screen with ML Kit liveness challenges
- Processing screen — API calls to backend
- Result screen — ACCEPT/REJECT/MANUAL_REVIEW display
- TFLite quality model running on-device for camera feedback
- ECDSA payload signing implemented
- End-to-end flow working on real Android device

---

### Criteria — Did it work?

**Green — Full flow working**
- End-to-end verification completes on real device in < 10 seconds
- Quality feedback appears in real-time on camera screen
- Liveness challenges complete successfully for a real user
- Result screen shows correct decision from backend

**Yellow — Partial flow**
- Camera screen works but quality feedback slow or missing
- Liveness challenge works but no TFLite integration
- End-to-end works but only on emulator not real device
- Some screens work, result screen incomplete

**Red — Blocked**
- Camera stream not working at all
- TFLite models not loading
- Cannot connect to backend from device

---

### What to say if Yellow (partial app)
> "The Flutter application implements the core verification user
> interface including document capture with ML Kit boundary detection,
> selfie capture with active liveness challenges, and result display.
> Real-time document quality feedback via on-device TFLite inference
> was implemented but [specific limitation]. The application
> demonstrates the complete verification user journey and validates
> the API contract between mobile client and Django backend.
> Full production polish including [what was skipped] is designated
> as post-thesis implementation work."

---

### What to say if Red (app mostly not working)
> "The mobile application was developed to the point of demonstrating
> [what does work]. Due to [specific technical challenge — be honest],
> the complete end-to-end mobile flow was not achieved within the
> thesis timeline. The verification pipeline is fully functional via
> the REST API and is demonstrated through [Postman / CLI demo / screen
> recording of partial flow]. The contribution of the thesis is the
> AI pipeline and its evaluation — the mobile integration is the
> deployment vehicle, and its partial state does not affect the
> validity of the experimental results."

---

### Checkpoint questions
- Does end-to-end flow work on real device? Yes / No / Partially
- Average end-to-end time on device? ____seconds
- Does real-time quality feedback work? Yes / No
- Do liveness challenges complete successfully? Yes / No
- What was the hardest Flutter problem you hit?

---

---

# MILESTONE 8
## Fairness Evaluation
### Target completion: End of Week 18

---

### What you are building
- Face embedding FAR/FRR broken down by demographic subgroup
- Liveness APCER/BPCER broken down by subgroup if data permits
- Subgroup disparity documented honestly
- At least one mitigation strategy discussed even if not implemented

---

### Criteria — Did it work?

**Green**
- Subgroup breakdown table produced for at least face embedding
- Disparity quantified (e.g. FAR difference between groups X and Y)
- Discussion written with honest analysis

**Yellow**
- Limited subgroup data makes full analysis impossible
- Partial breakdown on available groups only

**Red**
- No subgroup data available at all

---

### What to say if Yellow or Red
> "Fairness evaluation was conducted on available demographic subgroups
> within the LFW and CelebA-Spoof datasets. The limited demographic
> diversity of these public datasets constrains the scope of the
> analysis — a known limitation of academic anti-spoofing and face
> verification research. Available results are presented in Table X.
> A production deployment would require a purpose-built diverse
> evaluation set, which is identified as a critical future work item."

---

---

# OVERALL THESIS HEALTH CHECK
## Use this at any point you feel uncertain

Answer each honestly:

| Question | Answer |
|---|---|
| Do I have at least 2 complete AI experiments with results? | Yes / No |
| Do I have a compression study with at least 6 of 9 rows? | Yes / No |
| Do I have a decision engine comparison with results? | Yes / No |
| Is the architecture documented with reasoning? | Yes / No |
| Is the security analysis written? | Yes / No |
| Do I have honest limitations for everything that did not work? | Yes / No |

**If you answered Yes to all 6:** You have a thesis. Write it up.

**If you answered Yes to 4–5:** You have a thesis. The missing items
become limitations and future work sections.

**If you answered Yes to 3 or fewer:** Come to Claude immediately.
We need to triage and decide what to prioritise in remaining time.

---

---

# THE UNIVERSAL THESIS FALLBACK STATEMENT
## When results are not what you hoped

This paragraph works for almost any underperforming result. Fill in
the blanks:

> "The [model/component] achieved [actual result] against a target of
> [target result]. Analysis of [what you examined — confusion matrix,
> loss curves, error examples] reveals that the gap is primarily
> attributable to [honest reason — domain gap / dataset size /
> architecture limitation / time constraint]. This finding is
> consistent with [cite a paper that had similar results or discussed
> this challenge]. Future work addressing [specific improvement]
> would be expected to close this gap. Importantly, the result
> nonetheless demonstrates [what it does show — that the approach
> is feasible / that the specific challenge is quantifiable /
> that the compression tradeoff exists]."

---

---

# WHEN TO COME BACK TO CLAUDE

Come back at the end of every milestone with your checkpoint answers.
Also come back immediately if:

- A model is not converging after 10 epochs
- An export pipeline is failing and you have tried for more than 2 days
- You are more than 2 weeks behind the milestone target
- You are not sure if a result is good enough to report
- You want to cut something and need to know what is safest to cut
- You have a result you do not understand and need help interpreting it

When you come back, lead with:
1. Which milestone you just finished
2. Your checkpoint answers
3. The specific question or problem

This document will be updated as the project progresses.

---

*Last updated: March 2026*
*Thesis submission deadline: _______________*
