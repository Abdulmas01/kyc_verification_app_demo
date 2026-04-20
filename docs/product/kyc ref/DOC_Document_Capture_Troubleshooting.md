Status: Execution Plan

# Document Capture Troubleshooting Guide

This guide summarizes what was changed in the document capture pipeline, how
to verify it is working on device, and how to debug common failures.

---

## What We Changed (Summary)

- Moved document quality inference to an isolate.
- Added cross-device camera format support (`YUV420` + `BGRA8888`).
- Enforced 4-D input tensor shape (`[1][H][W][3]`) to avoid PAD errors.
- Read model input/output shapes at runtime to avoid shape mismatches.
- Added lifecycle pause/resume to stop and restart streams safely.
- Added one-time device metadata logging using the app logger.

---

## One-Time Meta Log (What to Expect)

You should see one log at startup similar to:

```
QualityIsolate meta: format=1, size=720x480, planes=[true, true, true],
p0r=720, p0p=1, p1r=720, p1p=2, p2r=720, p2p=2,
inputShape=[1, 224, 224, 3], outputShape=[1, 5]
```

### What it tells you
- `format`: Camera format (`1` is usually `YUV420`, `2` often `BGRA8888`).
- `size`: Raw camera frame size.
- `planes`: Whether plane1/plane2 exist (required for YUV).
- `p0r/p0p`: Plane0 row stride/pixel stride.
- `inputShape/outputShape`: TFLite tensor shapes from the model.

---

## Common Errors and Fixes

### 1) `PAD failed to prepare (4 != 1)`
**Cause**
- The model received a 1-D input (flat list) instead of `[1][H][W][3]`.

**Fix**
- Ensure input is passed as a 4-D list.
- See `lib/core/ml/quality_isolate.dart` for `_imageToTensor(...)`.

---

### 1b) Correct label order (critical)
**Cause**
- The label order used in the app does not match the model’s export order.
- This causes incorrect user guidance (e.g., blur shows as dark).

**Fix**
- Update `lib/core/ml/quality_model.dart` `_labels` to match the model export.
- Keep a comment or link to the model’s `labels.txt` to prevent regressions.

---

### 2) `Missing UV planes for YUV420 frame`
**Cause**
- Camera is not delivering YUV planes as expected.

**Fix**
- Ensure the camera is requested with:
  `imageFormatGroup: ImageFormatGroup.yuv420`.
- If device only supports BGRA, the isolate will switch to BGRA path.

---

### 3) `Unsupported image format`
**Cause**
- Device returned a format we do not handle.

**Fix**
- Add a conversion path for the new format in
  `lib/core/ml/quality_isolate.dart`.

---

### 4) Status message never changes
**Cause**
- Inference is failing, so `updateQuality()` never runs.

**Fix**
- Check for TFLite errors.
- Confirm isolate is running (meta log appears).
- Remember: the header text is static; only `uiState.statusMessage` updates.

---

### 5) Timeouts from `predict(...)`
**Cause**
- Inference is too slow for the timeout (device load or heavy frames).

**Fix**
- Increase timeout in `QualityIsolate.predict`.
- Lower resolution or increase frame stride.
- Verify isolate is not blocked by heavy GC.

---

### 6) `Unable to acquire a buffer item` (ImageReader)
**Symptom**
```
W/ImageReader_JNI: Unable to acquire a buffer item, very likely client tried to acquire more than maxImages buffers
```

**Cause**
- The camera stream callback is holding onto `CameraImage` too long.
- Awaiting heavy work inside the callback keeps buffers open.

**Fix**
- Copy camera plane bytes immediately.
- Release the frame quickly, then process on a separate future.
- Use a payload/transfer pattern (`buildPayload` → `predictPayload`) so the
  stream callback returns fast.

---

## Verification Checklist (Before Release)

- Meta log appears once.
- Status message updates while camera is running.
- No repeated `PAD` or TFLite errors.
- Stream pauses when app is backgrounded, resumes on return.
- Frame stride adapts to device performance.

---

## Where to Look in Code

- `lib/core/ml/quality_isolate.dart`
  - Image conversion, tensor building, TFLite run, error handling.
- `lib/core/features/kyc/presentation/steps/verification_flow/document_capture_step.dart`
  - Stream handling, lifecycle pause/resume, inference throttle.
- `lib/core/utils/logger.dart`
  - Central log helper used by isolate and UI.
