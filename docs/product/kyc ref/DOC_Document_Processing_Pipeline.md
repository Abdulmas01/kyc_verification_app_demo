# Document Processing Pipeline
## KYC Thesis — OCR, Field Extraction, Edge Cases and Solutions

---

## Pipeline Order (Never Changes)

```
MOBILE
  1. Quality Classifier (TFLite)     → gate: is image processable?
  2. Boundary Detection (ML Kit)     → find card corners
  3. Perspective Warp (OpenCV)       → flatten the document

SERVER
  4. OCR (ML Kit primary)            → extract all text blocks
  5. Field Extraction (your code)    → get name, ID, dates
  6. Tesseract fallback              → if ML Kit confidence < 0.65
```

Quality always runs first. No point running OCR on a blurry image.

---

## What You Train vs What Already Exists

| Step | You Build | Already Exists |
|---|---|---|
| Quality Classifier | ✅ Train on synthetic data | — |
| Boundary Detection | Integration only | ML Kit |
| Perspective Warp | 10 lines OpenCV | OpenCV library |
| OCR | Integration only | ML Kit / Tesseract |
| Field Extraction | ✅ Write regex rules | — |
| MRZ Parser | ✅ Write parser (or use library) | python-mrz library |

---

## Edge Case 1 — Perspective Warp Corner Problems

### Problem
ML Kit returns 4 corner points but they are unreliable in certain conditions.

**Corner drift:**
Physical corner is in shadow → ML Kit detects a point 2cm inside
the card edge → warp cuts off part of the document → OCR misses
fields entirely.

**Corner ordering:**
ML Kit does not guarantee point order (top-left, top-right,
bottom-right, bottom-left). Wrong order → upside-down or mirrored
document image.

**Wrong aspect ratio:**
NIN cards are 85.6 × 54mm (ISO/IEC 7810 ID-1 standard).
If output dimensions are wrong → text gets squeezed → Tesseract
accuracy drops.

### Solution
```python
def order_corners(pts):
    """Sort 4 points into top-left, top-right, bottom-right, bottom-left."""
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]   # top-left: smallest sum
    rect[2] = pts[np.argmax(s)]   # bottom-right: largest sum
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # top-right: smallest diff
    rect[3] = pts[np.argmax(diff)]  # bottom-left: largest diff
    return rect

def warp_document(image, corners):
    rect = order_corners(corners)
    # Output dimensions — ID-1 card aspect ratio
    output_w, output_h = 856, 540  # 10x scale of mm dimensions
    dst = np.array([
        [0, 0],
        [output_w - 1, 0],
        [output_w - 1, output_h - 1],
        [0, output_h - 1]
    ], dtype="float32")
    M = cv2.getPerspectiveTransform(rect, dst)
    return cv2.warpPerspective(image, M, (output_w, output_h))
```

---

## Edge Case 2 — Document Photo Quality (Face Region)

### Problem
The printed face photo on the ID card is:
- Small (~3cm × 3.5cm physical)
- Already compressed once when printed
- Photographed again by mobile camera
- May be only 80×90 pixels after cropping

MobileFaceNet expects a clean 112×112 face image.
Upscaling from 80×90 introduces blur.

### Impact on Face Matching
LFW benchmark assumes clean face photos. Real document
photos will produce lower similarity scores. Do not use
your LFW threshold directly for document-vs-selfie comparison.

### Solution
```python
# Upscale face crop to MobileFaceNet input size
face_crop = cv2.resize(face_crop, (112, 112),
                       interpolation=cv2.INTER_CUBIC)

# Use lower similarity threshold for document face matching
# LFW threshold: ~0.60
# Document photo threshold: ~0.45 (calibrate on real samples)
DOCUMENT_SIMILARITY_THRESHOLD = 0.45
```

**Thesis note:** Document this as a known limitation.
Real-world performance will be below LFW benchmark numbers.
This is expected and honest — mention it in limitations section.

---

## Edge Case 3 — Nigerian Document Generations

All currently in circulation simultaneously. Your extractor
must handle all of them.

| Document | Layout | Fields | Difficulty |
|---|---|---|---|
| Old NIMC slip (paper) | Labels above values | NIN, surname, first name, DOB | Easy |
| Laminated NIN card | Labels BELOW values | Same fields | Medium |
| Current NIMC smart card | Has MRZ at bottom | Full fields + MRZ | Easiest via MRZ |
| Voter's card (PVC) | Completely different | VIN not NIN | Different template |
| Driver's license | Varies by state | Licence no., class, expiry | Hardest |

**Thesis scope:** Target NIMC smart card only (has MRZ).
Other types → future work.

**Startup scope:** Add one template at a time per customer request.
Each template = one field extractor rule set = half day of work.

---

## Edge Case 4 — OCR Character Substitution Errors

Even on a clean image ML Kit makes mistakes. The dangerous ones:

```
0 vs O  → "N0NAME"   vs "NONAME"
1 vs I  → "1BRAHIM"  vs "IBRAHIM"
1 vs l  → "SAL1HU"   vs "SALIHU"
5 vs S  → "5ALIHU"   vs "SALIHU"
8 vs B  → "A8UL"     vs "ABUL"
```

### Solution — Tolerant Regex

```python
# NIN number — 11 digits, tolerant of O/0 confusion
NIN_PATTERN = re.compile(r'\b[0-9O]{11}\b')

def clean_nin(raw):
    # Replace O with 0 in numeric fields
    return raw.replace('O', '0').replace('o', '0')

# Name — tolerant of 1/I and 5/S confusion
def clean_name(raw):
    corrections = {'0': 'O', '1': 'I', '5': 'S', '8': 'B'}
    # Only apply to alphabetic positions
    # (don't correct numbers in numeric fields)
    return raw  # apply heuristically per field type
```

---

## Edge Case 5 — Date Format Variations

Nigerian documents use multiple date formats. All seen in the wild:

```
15-04-1998
15/04/1998
15 APR 1998
APR 15, 1998
1998-04-15
15041998     ← no separator (rare but exists)
```

### Solution — Multi-format Parser

```python
from dateutil import parser as dateparser

DATE_PATTERNS = [
    r'\b(\d{2}[-/]\d{2}[-/]\d{4})\b',      # 15-04-1998 or 15/04/1998
    r'\b(\d{2}\s[A-Z]{3}\s\d{4})\b',        # 15 APR 1998
    r'\b([A-Z]{3}\s\d{2},?\s\d{4})\b',      # APR 15, 1998
    r'\b(\d{4}[-/]\d{2}[-/]\d{2})\b',       # 1998-04-15
    r'\b(\d{8})\b',                           # 15041998
]

def extract_date(text):
    for pattern in DATE_PATTERNS:
        match = re.search(pattern, text)
        if match:
            try:
                return dateparser.parse(match.group(1)).date()
            except:
                continue
    return None
```

---

## Edge Case 6 — Name Field Variations

```
Single field:   "SALIHU ABDUL MOHAMMED AUWAL"
Split fields:   Surname: SALIHU   Given Names: ABDUL MOHAMMED
Hyphenated:     ABDULLAHI-SALIHU
With prefix:    Alhaji SALIHU ABDUL
With title:     Dr. SALIHU ABDUL
```

### Solution
```python
PREFIXES_TO_STRIP = ['alhaji', 'alhaja', 'dr', 'mr', 'mrs', 'prof', 'engr']

def extract_name(text_blocks):
    # Try labelled fields first
    surname_match = re.search(r'surname[:\s]+([A-Z\-]+)', text, re.I)
    given_match = re.search(r'(given|first|other)\s*name[s]?[:\s]+([A-Z\s\-]+)', text, re.I)

    if surname_match and given_match:
        return f"{surname_match.group(1)} {given_match.group(2)}".strip()

    # Fall back to longest all-caps sequence
    caps_sequences = re.findall(r'\b[A-Z][A-Z\s\-]{4,}\b', text)
    if caps_sequences:
        name = max(caps_sequences, key=len).strip()
        # Strip known prefixes
        for prefix in PREFIXES_TO_STRIP:
            name = re.sub(f'^{prefix}\.?\s+', '', name, flags=re.I)
        return name

    return None
```

---

## The MRZ Strategy (Most Important)

### What Is MRZ
Machine Readable Zone — two lines of standardised text at the
bottom of ICAO-compliant ID cards. Same format regardless of
country or card design.

```
Line 1: IDNGA1234567890<<<<<<<<<<<<<<<
Line 2: 9804154M2804141NGA<<<<<<<<<<<6
Line 3: SALIHU<<ABDUL<<MOHAMMED<<<<<<<
```

### What You Can Extract
From MRZ alone, with no layout knowledge:
- Document number: 1234567890
- Date of birth: 980415 → 1998-04-15
- Sex: M
- Expiry date: 280414 → 2028-04-14
- Nationality: NGA
- Surname: SALIHU
- Given names: ABDUL MOHAMMED

### Why This Changes Everything
MRZ format is international standard (ICAO 9303).
Nigeria, Ghana, Kenya, South Africa — all use the same format.
Your field extractor becomes largely country-agnostic
if you target MRZ first.

### Extraction Priority (Always Follow This Order)

```python
def extract_fields(ocr_text, ocr_blocks):
    # Step 1 — Try MRZ first (most reliable)
    mrz = detect_mrz(ocr_text)
    if mrz and mrz.valid:
        return {
            'name': mrz.surname + ' ' + mrz.given_names,
            'id_number': mrz.document_number,
            'date_of_birth': mrz.date_of_birth,
            'expiry_date': mrz.expiry_date,
            'nationality': mrz.nationality,
            'source': 'mrz',
            'confidence': 0.95
        }

    # Step 2 — Try labelled template matching
    fields = try_template_extraction(ocr_text)
    if fields['completeness'] > 0.7:
        fields['source'] = 'template'
        fields['confidence'] = 0.75
        return fields

    # Step 3 — Positional heuristics (last resort)
    fields = try_heuristic_extraction(ocr_text, ocr_blocks)
    fields['source'] = 'heuristic'
    fields['confidence'] = 0.50
    return fields  # flag for manual review
```

### Recommended Library
```bash
pip install mrz
```
Handles ICAO 9303 TD1/TD2/TD3 formats.
Includes checksum validation (catches OCR errors in MRZ).
Returns structured data with validity flag.

---

## Tesseract Setup (Server Side)

### The Real Problem
Not the Python code — the server installation.

```dockerfile
# Dockerfile — required system dependencies
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-yor \
    tesseract-ocr-hau \
    libtesseract-dev \
    && rm -rf /var/lib/apt/lists/*
```

Without this in your Dockerfile, pytesseract will install
fine but throw "tesseract not found" at runtime.

### DPI Fix (Critical for Accuracy)
```python
import cv2
import pytesseract

def tesseract_ocr(image):
    # Upscale to 300 DPI equivalent before Tesseract
    # Mobile camera crops are typically 72-150 effective DPI
    scale_factor = 2.5
    upscaled = cv2.resize(image, None,
                          fx=scale_factor, fy=scale_factor,
                          interpolation=cv2.INTER_CUBIC)

    # Use image_to_data for confidence scores per word
    data = pytesseract.image_to_data(
        upscaled,
        lang='eng',
        config='--psm 6',  # assume uniform block of text
        output_type=pytesseract.Output.DICT
    )
    return data
```

### When Tesseract Triggers
```python
ML_KIT_CONFIDENCE_THRESHOLD = 0.65

if mlkit_confidence < ML_KIT_CONFIDENCE_THRESHOLD:
    result = tesseract_ocr(document_image)
    source = 'tesseract'
else:
    source = 'mlkit'
```

---

## ocr_confidence Score for Decision Engine

This is the only OCR number that matters for the thesis evaluation.

```python
def compute_ocr_confidence(extracted_fields, source):
    # Field completeness — how many required fields extracted
    required = ['name', 'id_number', 'date_of_birth']
    completeness = sum(
        1 for f in required if extracted_fields.get(f)
    ) / len(required)

    # Source reliability weight
    source_weight = {
        'mrz': 1.00,
        'template': 0.85,
        'heuristic': 0.60,
        'tesseract': 0.75
    }

    # Field validation — does the NIN pass checksum?
    format_valid = validate_nin_format(extracted_fields.get('id_number'))

    ocr_confidence = (
        completeness * 0.5 +
        source_weight[source] * 0.3 +
        (1.0 if format_valid else 0.0) * 0.2
    )

    return round(ocr_confidence, 4)
```

---

## Realistic Time Estimates

| Task | Zero experience | Have done OCR before |
|---|---|---|
| ML Kit integration | 2–3 hours | 1 hour |
| Perspective warp | 1 day | 2–3 hours |
| MRZ parser setup | 2 hours | 1 hour |
| NIN field extractor | 1–2 days | Half day |
| Tesseract Docker setup | Half day | 1–2 hours |
| Testing on real docs | 1–2 days | 1 day |
| **Total** | **4–5 days** | **2–3 days** |

The one thing experience does not shortcut: testing on real
document samples. Always budget 1 day minimum regardless
of experience level.

---

## Thesis Scope — What to Claim and Not Claim

**Claim:**
- Integration and evaluation of OCR pipeline for Nigerian NIN documents
- MRZ-first extraction strategy achieving reliable field extraction
- ocr_confidence and field_valid_score signals as inputs to decision engine
- Field format validation and cross-consistency checks as OCR security layer

**Do not claim:**
- Novel OCR model (you trained nothing for OCR)
- Layout understanding (you used rules not a learned model)
- Layout consistency checks or image manipulation detection
  (out of scope — designated future work)
- Multi-country support (thesis scope is NIN only)

**Limitations section:**
- OCR security layer catches opportunistic fraud only — not
  sophisticated forgery without database verification
- Multiple NIN card generations require multiple extraction strategies
- Cross-document-type generalisation is future work

---

## Security — What the OCR Layer Can and Cannot Catch

### What You Actually Implement

```python
# 1. NIN Format Validation
def validate_nin(nin_string):
    cleaned = nin_string.replace('O', '0').replace('I', '1')
    if not re.match(r'^\d{11}$', cleaned):
        return False, 'INVALID_FORMAT'
    if cleaned[0] == '0':
        return False, 'INVALID_START_DIGIT'
    return True, 'VALID'

# 2. Cross-Field Consistency
def cross_validate_fields(fields):
    flags = []

    if fields.get('date_of_birth'):
        age = calculate_age(fields['date_of_birth'])
        if age < 18:
            flags.append('DOB_UNDERAGE')
        if age > 100:
            flags.append('DOB_IMPLAUSIBLE')

    if fields.get('expiry_date'):
        if fields['expiry_date'] < date.today():
            flags.append('DOCUMENT_EXPIRED')

    if fields.get('issue_date') and fields.get('expiry_date'):
        if fields['issue_date'] >= fields['expiry_date']:
            flags.append('DATE_LOGIC_IMPOSSIBLE')

    if fields.get('id_number'):
        valid, reason = validate_nin(fields['id_number'])
        if not valid:
            flags.append(f'NIN_{reason}')

    return flags

# 3. OCR Confidence Anomaly
def detect_confidence_anomaly(ocr_blocks):
    confidences = [b['confidence'] for b in ocr_blocks
                   if b['confidence'] > 0]
    if len(confidences) < 3:
        return False
    mean_conf = np.mean(confidences)
    std_conf = np.std(confidences)
    anomalous = [b for b in ocr_blocks
                 if b['confidence'] < mean_conf - (2 * std_conf)]
    return len(anomalous) > 0
```

### What This Catches vs What It Does Not

| Attack | Caught? | Why |
|---|---|---|
| Wrong NIN format | ✅ | Format validation |
| Expired document | ✅ | Expiry date check |
| Impossible dates (issue after expiry) | ✅ | Cross-consistency |
| Person under 18 | ✅ | Age check |
| OCR text overlay (poor quality) | ✅ Partially | Confidence anomaly |
| Well-crafted fake correct format | ❌ | Cannot detect without DB |
| Photoshop overlay matching font | ❌ | No forensics model |
| Real NIN with wrong person's photo | ❌ | Face matching handles this |

### Out of Scope — Future Work

Layout consistency checks and image manipulation detection
require either a trained document forensics model or a
geometric template matching system with a labelled dataset
of genuine vs fake documents. Neither is feasible within
the thesis timeline. Sophisticated document forgery is
addressed by the face matching layer, not OCR.

---

*Document created: March 2026*
*Part of: KYC AI Thesis — Master of Science, Embedded AI, ATBU Bauchi*
