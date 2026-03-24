# Document Capture Performance Notes

## Why we changed the camera pipeline

Problem observed during testing:
- Camera preview was **choppy / laggy** during document capture.

Root cause:
- We were doing **YUV → RGB conversion + TFLite inference on the UI thread**.
- Even with frame skipping, this heavy work blocked the UI thread.

Impact:
- Poor user experience (stuttering preview)
- Risk of dropped frames and delayed auto‑capture

---

## What we changed

1) **Moved inference to an isolate**
- New file: `lib/core/ml/quality_isolate.dart`
- Runs conversion + model inference off the UI thread
- Uses `TransferableTypedData` to pass camera planes efficiently

2) **Correctness + performance fixes inside the isolate**
- Standard BT.601 YUV → RGB coefficients (more accurate colors)
- Byte buffer + `Image.fromBytes` (faster conversion)
- Mean/std normalization to match ImageNet training

3) **Lowered camera resolution**
- `ResolutionPreset.high` → `ResolutionPreset.medium`
- Reduces processing cost without breaking UX

4) **Dynamic frame stride**
- Processes fewer frames when inference is slow
- Increases stride when avg inference time > 80ms
- Decreases stride when avg inference time < 40ms
- Keeps UI smooth across different devices

5) **Benchmark logging**
- Logs average inference time every 30 samples
- Helps tune stride + resolution and compare devices

6) **Cross‑device camera format support**
- Handles `YUV420` and `BGRA8888` frames safely
- Fallback error if an unsupported format appears
- Requests `ImageFormatGroup.yuv420` when opening the camera

7) **Model I/O shape safety**
- Reads input/output tensor shapes from TFLite at runtime
- Resizes frames to the actual model input size
- Allocates output dynamically and flattens safely
- Uses a 4‑D input tensor (`[1][H][W][3]`) to avoid PAD errors

8) **Isolate resilience + lifecycle safety**
- Catches inference errors in the isolate and returns them to the UI
- Handles timeouts in the stream callback (skips a frame vs crashing)
- Uses `WidgetsBindingObserver` to pause/resume stream on app lifecycle changes

9) **Structured logging**
- Logs one‑time isolate metadata (format, strides, input/output shapes)
- Uses the app logger (`lib/core/utils/logger.dart`) for consistency

10) **Label order alignment**
- Ensures `_labels` order matches the model’s exported label order.
- Prevents wrong guidance text (e.g., blur showing as dark).

---

## Where this lives in code

- `lib/core/ml/quality_isolate.dart`
  - Isolate entry, format conversion, TFLite inference, shape handling, meta log
- `lib/core/features/kyc/presentation/steps/verification_flow/document_capture_step.dart`
  - Starts isolate, throttles frames, logs performance, lifecycle pause/resume
 - `lib/core/utils/logger.dart`
  - Shared logger used by isolate + UI

---

## Why this is the “production” approach

Separating heavy work from the UI thread is the standard way
to keep camera previews smooth on mid‑range devices.

This design scales better because:
- Works on lower‑end phones
- Avoids UI jank under load
- Gives us measurable performance metrics

---

## Notes for future you

If preview becomes choppy again:
- Check average inference log
- Increase `_frameStride` or keep resolution lower
- Confirm isolate is running

If you see TFLite errors like:
`PAD failed to prepare (4 != 1)`
- The input was likely passed as a flat list.
- Ensure the model input is a 4‑D tensor (`[1][H][W][3]`).

If the status message doesn't update:
- Verify inference is succeeding (no TFLite errors).
- The static header ("Place your ID inside the frame") does not change.
- The dynamic status is `uiState.statusMessage`.

---

## Quick Troubleshooting Checklist

- Isolate starts? Check for the one‑time meta log.
- Format mismatch? Ensure `ImageFormatGroup.yuv420` is requested.
- Output mismatch? Check `outputShape` in meta log.
- Frequent timeouts? Increase timeout or reduce resolution/stride.
