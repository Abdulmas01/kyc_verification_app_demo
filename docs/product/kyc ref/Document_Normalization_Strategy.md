# Document Normalization Strategy (Thesis vs Production)

This document explains the **current best option for the thesis** and how to
evolve it into a reusable production package later.

---

## Thesis Choice (Best for Timeline + Stability)

**Approach:** ML Kit Object Detection → bounding box → crop → resize

### Why this is the right thesis choice
- **Fast to implement** in Flutter
- **Stable enough** for clean document captures
- **No native OpenCV** or platform channels required
- Keeps focus on the AI evaluation, not vision pipeline engineering

### Current Flow (Implemented)
1. Capture image from camera
2. Run ML Kit Object Detection (single image)
3. If a document is detected, take the **largest bounding box**
4. Crop to bounding box
5. Resize to **856×540** (ID‑1 aspect ratio)
6. Save as normalized document image

### Code Reference
See:
- `lib/core/utils/image_utils.dart`
- `lib/core/features/kyc/presentation/steps/verification_flow/document_capture_step.dart`

---

## Limitations (Accepted for Thesis)

This method **does not** do true perspective correction. It will:
- Work well for straight captures
- Be less accurate for angled or skewed documents
- Rely on the user’s alignment (guided by the overlay)

For a thesis prototype, this is acceptable and **honest** to report.

---

## Production Upgrade Path (Reusable Package Plan)

If you want a **reusable production package** later, the upgrade path is:

### Option A — ML Kit Document Scanner (Recommended)
Use Google’s document scanner to get true edge‑aligned output.

**Pros**
- Accurate 4‑corner detection
- Perspective‑corrected output
- Less custom code

**Cons**
- Platform‑specific integration
- SDK dependency

### Option B — Native OpenCV (Full Control)
Use OpenCV to detect edges + corners + perspective warp.

**Pros**
- Full control
- Works offline
- No ML Kit dependency

**Cons**
- Most complex
- Requires platform channels or native plugin
- Heavier maintenance

---

## Reusable Package Design (Suggested)

Create a package called **`doc_normalizer`** with two layers:

### 1) Core Interface (shared)
```dart
abstract class DocumentNormalizer {
  Future<File> normalize({
    required String inputPath,
  });
}
```

### 2) Implementations
- `MlKitBoundingBoxNormalizer` (thesis / lightweight)
- `MlKitScannerNormalizer` (production)
- `OpenCvNormalizer` (full control / enterprise)


### Output Contract
Always return:
- Normalized image file path
- Output size 856×540
- Metadata: method used, confidence (if available)

---

## What to Say in the Thesis

> “For the prototype, document normalization is implemented as a bounding‑box
> crop using ML Kit object detection followed by resizing to ID‑1 aspect ratio.
> This approach is chosen for its stability and simplicity within the thesis
> timeline. Full perspective correction via 4‑corner detection is planned as
> future work and will be packaged as a reusable normalization module for
> production deployments.”

