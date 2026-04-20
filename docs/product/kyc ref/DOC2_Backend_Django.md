Status: Execution Plan

# KYC Thesis — Document 2: Backend Implementation Plan
## Django + Django REST Framework + PostgreSQL

> **Prerequisites:** Complete Document 1 first. You need the exported model files
> (`decision_engine.pkl`, `face_embedder.onnx`, `liveness.onnx`) before wiring
> up the backend. Everything else can be built in parallel.

---

## Tech Stack Decision

| Layer | Choice | Why |
|---|---|---|
| Framework | Django 5.0 + DRF | You know it, admin panel is free |
| Database | PostgreSQL 16 | Production-grade, JSONB for audit logs |
| ML Inference | ONNX Runtime + scikit-learn | Load trained models directly |
| OCR | Tesseract + MRZ (server-authoritative) | Reproducible, consistent with server-side decisions |
| Auth | DRF SimpleJWT | Stateless, mobile-friendly |
| Storage | Local / S3 (optional) | Encrypted doc images for manual review only |
| Task Queue | Celery + Redis | Async manual review notifications |
| Deployment | Docker + docker-compose | Reproducible, thesis demo-ready |

---

## Project Structure

```
kyc-backend/
├── config/
│   ├── settings/
│   │   ├── base.py
│   │   ├── development.py
│   └── └── production.py
│   ├── urls.py
│   └── wsgi.py
│
├── apps/
│   ├── verification/          # Core KYC logic
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── admin.py           # Manual review console
│   │   ├── services/
│   │   │   ├── ocr_service.py
│   │   │   ├── decision_engine.py
│   │   │   └── audit_service.py
│   │   └── tests/
│   │
│   ├── ml/                    # ML model loading + inference
│   │   ├── apps.py            # Load models at startup
│   │   ├── inference.py       # Run ONNX models
│   │   └── models_registry.py # Singleton model store
│   │
│   └── accounts/              # API key management for businesses
│       ├── models.py
│       ├── views.py
│       └── authentication.py
│
├── models/                    # Trained model files from Doc 1
│   ├── decision_engine.pkl
│   ├── face_embedder.onnx
│   └── liveness.onnx
│
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── manage.py
```

---

## Step 1 — Project Setup

```bash
# Create project
mkdir kyc-backend && cd kyc-backend
python -m venv venv && source venv/bin/activate

pip install django==5.0 \
            djangorestframework==3.15 \
            djangorestframework-simplejwt==5.3 \
            django-cors-headers==4.3 \
            psycopg2-binary==2.9 \
            onnxruntime==1.17 \
            scikit-learn==1.4 \
            joblib==1.3 \
            pillow==10.2 \
            pytesseract==0.3 \
            celery==5.3 \
            redis==5.0 \
            python-dotenv==1.0 \
            drf-spectacular==0.27   # Auto API docs (Swagger)

django-admin startproject config .
python manage.py startapp verification
python manage.py startapp ml
python manage.py startapp accounts
```

---

## Step 2 — Settings

```python
# config/settings/base.py

from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()
BASE_DIR = Path(__file__).resolve().parent.parent.parent

SECRET_KEY = os.getenv("DJANGO_SECRET_KEY")
DEBUG = False

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    "drf_spectacular",
    # Local
    "apps.verification",
    "apps.ml",
    "apps.accounts",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("DB_NAME", "kyc_db"),
        "USER": os.getenv("DB_USER", "kyc_user"),
        "PASSWORD": os.getenv("DB_PASSWORD"),
        "HOST": os.getenv("DB_HOST", "localhost"),
        "PORT": os.getenv("DB_PORT", "5432"),
    }
}

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        "apps.accounts.authentication.APIKeyAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "10/minute",
        "user": "100/hour",    # max 100 verifications per hour per API key
    },
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

# ML Models path — loaded at startup by apps/ml/apps.py
ML_MODELS_DIR = BASE_DIR / "models"

# Celery
CELERY_BROKER_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = os.getenv("REDIS_URL", "redis://localhost:6379/0")

CORS_ALLOWED_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
```

---

## Step 3 — Database Models

```python
# apps/verification/models.py

from django.db import models
import uuid

class VerificationSession(models.Model):
    """
    One record per KYC verification attempt.
    This is the core audit log and the training data for the decision engine.
    """

    class Decision(models.TextChoices):
        ACCEPT        = "ACCEPT",        "Accepted"
        REJECT        = "REJECT",        "Rejected"
        MANUAL_REVIEW = "MANUAL_REVIEW", "Manual Review Required"
        PENDING       = "PENDING",       "Pending"

    class ManualDecision(models.TextChoices):
        APPROVED = "APPROVED", "Approved by Reviewer"
        REJECTED = "REJECTED", "Rejected by Reviewer"
        PENDING  = "PENDING",  "Awaiting Review"

    # Identity
    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    session_token  = models.CharField(max_length=64, unique=True, db_index=True)
    api_key        = models.ForeignKey("accounts.APIKey", on_delete=models.SET_NULL, null=True)

    # AI Signals (authoritative server inference outputs + mobile metadata where applicable)
    face_similarity     = models.FloatField(null=True)
    liveness_score      = models.FloatField(null=True)
    ocr_confidence      = models.FloatField(null=True)
    doc_quality_score   = models.FloatField(null=True)
    field_valid_score   = models.FloatField(null=True)
    doc_boundary_conf   = models.FloatField(null=True)
    face_quality_score  = models.FloatField(null=True)
    challenge_success   = models.BooleanField(null=True)

    # Extracted Fields (from OCR)
    extracted_name      = models.CharField(max_length=200, blank=True)
    extracted_id_number = models.CharField(max_length=100, blank=True)
    extracted_dob       = models.DateField(null=True, blank=True)
    extracted_expiry    = models.DateField(null=True, blank=True)

    # Decision Engine Output
    risk_score      = models.FloatField(null=True)
    decision        = models.CharField(max_length=20, choices=Decision.choices, default=Decision.PENDING)
    reason_codes    = models.JSONField(default=list)    # ["LOW_LIVENESS", "OCR_LOW_CONF"]

    # Manual Review
    manual_decision = models.CharField(max_length=20, choices=ManualDecision.choices, default=ManualDecision.PENDING)
    reviewer_notes  = models.TextField(blank=True)
    reviewed_by     = models.ForeignKey("auth.User", on_delete=models.SET_NULL, null=True, blank=True)
    reviewed_at     = models.DateTimeField(null=True, blank=True)

    # Sensitive storage (only for manual review cases)
    encrypted_doc_image  = models.BinaryField(null=True, blank=True)
    encrypted_selfie     = models.BinaryField(null=True, blank=True)

    # Metadata
    model_version   = models.CharField(max_length=50, default="v1.0.0")
    app_version     = models.CharField(max_length=20, blank=True)
    device_os       = models.CharField(max_length=20, blank=True)
    attempt_number  = models.IntegerField(default=1)
    ip_address      = models.GenericIPAddressField(null=True, blank=True)

    # Timestamps
    created_at      = models.DateTimeField(auto_now_add=True, db_index=True)
    completed_at    = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["decision", "created_at"]),
            models.Index(fields=["manual_decision"]),
        ]

    def __str__(self):
        return f"Session {self.session_token[:8]} — {self.decision}"

    @property
    def is_flagged_for_review(self):
        return self.decision == self.Decision.MANUAL_REVIEW

    def get_signal_vector(self):
        """Returns the feature vector for decision engine input"""
        return [
            self.face_similarity    or 0.0,
            self.liveness_score     or 0.0,
            self.ocr_confidence     or 0.0,
            self.doc_quality_score  or 0.0,
            self.field_valid_score  or 0.0,
        ]
```

```python
# apps/accounts/models.py

from django.db import models
import secrets

class APIKey(models.Model):
    """
    Business customers authenticate with API keys.
    Each key has a rate limit and usage tracking.
    This is your startup billing anchor.
    """
    name            = models.CharField(max_length=200)      # "Acme Fintech Ltd"
    key             = models.CharField(max_length=64, unique=True, db_index=True)
    is_active       = models.BooleanField(default=True)
    monthly_limit   = models.IntegerField(default=1000)     # verifications per month
    verifications_used = models.IntegerField(default=0)
    created_at      = models.DateTimeField(auto_now_add=True)
    owner           = models.ForeignKey("auth.User", on_delete=models.CASCADE)

    def save(self, *args, **kwargs):
        if not self.key:
            self.key = f"kyc_{secrets.token_urlsafe(32)}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.key[:12]}...)"

    @property
    def is_within_limit(self):
        return self.verifications_used < self.monthly_limit
```

---

## Step 4 — ML Model Loading at Startup

This is the Django-specific pattern for loading ML models once at startup (not on every request):

```python
# apps/ml/apps.py

from django.apps import AppConfig
import logging

logger = logging.getLogger(__name__)

class MlConfig(AppConfig):
    name = "apps.ml"
    verbose_name = "ML Models"

    def ready(self):
        """
        Called once when Django starts.
        Loads all ML models into memory so they are ready for inference.
        """
        from .models_registry import ModelRegistry
        try:
            ModelRegistry.load_all()
            logger.info("✅ All ML models loaded successfully")
        except Exception as e:
            logger.error(f"❌ Failed to load ML models: {e}")
```

```python
# apps/ml/models_registry.py

import onnxruntime as ort
import joblib
import numpy as np
from django.conf import settings
import threading

class ModelRegistry:
    """
    Singleton that holds all loaded ML models in memory.
    Thread-safe — models are loaded once at startup.
    """
    _instance = None
    _lock = threading.Lock()

    _models = {
        "face_embedder":    None,
        "liveness":         None,
        "decision_engine":  None,
    }

    @classmethod
    def load_all(cls):
        models_dir = settings.ML_MODELS_DIR

        # Load ONNX models
        cls._models["face_embedder"] = ort.InferenceSession(
            str(models_dir / "face_embedder.onnx"),
            providers=["CPUExecutionProvider"]
        )
        cls._models["liveness"] = ort.InferenceSession(
            str(models_dir / "liveness.onnx"),
            providers=["CPUExecutionProvider"]
        )

        # Load scikit-learn decision engine
        cls._models["decision_engine"] = joblib.load(
            str(models_dir / "decision_engine.pkl")
        )

    @classmethod
    def get(cls, model_name):
        model = cls._models.get(model_name)
        if model is None:
            raise RuntimeError(f"Model '{model_name}' not loaded. Check startup logs.")
        return model
```

```python
# apps/ml/inference.py

import numpy as np
from .models_registry import ModelRegistry

def run_face_embedding(face_image_array: np.ndarray) -> np.ndarray:
    """
    face_image_array: float32 [1, 3, 112, 112] normalized -1 to 1
    Returns: float32 [128] L2-normalized embedding
    """
    session = ModelRegistry.get("face_embedder")
    input_name = session.get_inputs()[0].name
    output = session.run(None, {input_name: face_image_array})
    embedding = output[0][0]
    # L2 normalize
    norm = np.linalg.norm(embedding)
    return embedding / norm if norm > 0 else embedding

def run_liveness(frame_array: np.ndarray) -> float:
    """
    frame_array: float32 [1, 3, 128, 128] normalized 0-1
    Returns: float liveness_score 0-1
    """
    session = ModelRegistry.get("liveness")
    input_name = session.get_inputs()[0].name
    output = session.run(None, {input_name: frame_array})
    live_prob = float(output[0][0][1])  # index 1 = LIVE class
    return live_prob

def cosine_similarity(emb1: np.ndarray, emb2: np.ndarray) -> float:
    return float(np.dot(emb1, emb2) / (np.linalg.norm(emb1) * np.linalg.norm(emb2)))

def run_decision_engine(signal_vector: list) -> dict:
    """
    signal_vector: [face_similarity, liveness_score, ocr_confidence,
                    doc_quality_score, field_valid_score]
    Returns: {"risk_score": float, "decision": str, "reason_codes": list}
    """
    model = ModelRegistry.get("decision_engine")
    X = np.array([signal_vector], dtype=np.float64)
    prob_genuine = model.predict_proba(X)[0][1]

    # Decision thresholds
    if prob_genuine >= 0.70:
        decision = "ACCEPT"
    elif prob_genuine >= 0.40:
        decision = "MANUAL_REVIEW"
    else:
        decision = "REJECT"

    reason_codes = _compute_reason_codes(signal_vector, decision)

    return {
        "risk_score": round(1 - prob_genuine, 4),
        "genuine_probability": round(prob_genuine, 4),
        "decision": decision,
        "reason_codes": reason_codes
    }

def _compute_reason_codes(signals, decision):
    """Generate human-readable reason codes for the decision."""
    face_sim, liveness, ocr_conf, doc_quality, field_valid = signals
    codes = []

    if liveness < 0.50:    codes.append("LOW_LIVENESS")
    if face_sim < 0.55:    codes.append("LOW_FACE_SIMILARITY")
    if ocr_conf < 0.60:    codes.append("LOW_OCR_CONFIDENCE")
    if doc_quality < 0.50: codes.append("LOW_DOC_QUALITY")
    if field_valid < 0.60: codes.append("FIELD_VALIDATION_FAILED")

    return codes
```

---

## Step 5 — API Endpoints & Views

### Full URL Contract

```
POST   /api/v1/verify/start/           → Start verification session
POST   /api/v1/verify/upload/          → Upload images (server-authoritative)
GET    /api/v1/verify/{session_id}/    → Get session result
GET    /api/v1/verify/history/         → List sessions for this API key

POST   /api/v1/auth/token/             → Get JWT (admin users)
POST   /api/v1/auth/api-key/           → Create API key (businesses)

GET    /api/v1/admin/review-queue/     → List manual review cases
POST   /api/v1/admin/review/{id}/      → Submit manual decision
GET    /api/v1/admin/stats/            → Dashboard stats

GET    /api/schema/                    → OpenAPI schema (auto-generated)
GET    /api/docs/                      → Swagger UI
```

### Core Serializers

```python
# apps/verification/serializers.py

from rest_framework import serializers
from .models import VerificationSession
import re
from datetime import date

class StartSessionSerializer(serializers.Serializer):
    app_version   = serializers.CharField(max_length=20)
    device_os     = serializers.ChoiceField(choices=["android", "ios"])
    model_version = serializers.CharField(max_length=50, default="v1.0.0")

class UploadVerificationSerializer(serializers.Serializer):
    session_token = serializers.CharField(max_length=64)
    document_image = serializers.ImageField()   # normalized document image
    selfie_image   = serializers.ImageField()   # selfie image
    model_version  = serializers.CharField(max_length=50, default="v1.0.0")
    app_version         = serializers.CharField(max_length=20, required=False)
    attempt_number      = serializers.IntegerField(min_value=1, max_value=5, default=1)

    def validate(self, data):
        # Hard reject: liveness too low regardless of other scores
        if data.get("liveness_score", 1) < 0.20:
            data["_hard_reject"] = "LIVENESS_TOO_LOW"

        # Hard reject: document expired
        expiry = data.get("extracted_expiry")
        if expiry and expiry < date.today():
            data["_hard_reject"] = "DOCUMENT_EXPIRED"

        return data

class VerificationResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = VerificationSession
        fields = [
            "id", "session_token", "decision", "risk_score",
            "reason_codes", "created_at", "completed_at"
        ]
        read_only_fields = fields
```

### Core Views

```python
# apps/verification/views.py

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
import secrets, logging

from .models import VerificationSession
from .serializers import (
    StartSessionSerializer,
    UploadVerificationSerializer,
    VerificationResultSerializer,
)
from .services.ocr_service import run_ocr_on_document
from .services.decision_engine import make_decision
from .services.audit_service import log_verification
from apps.accounts.authentication import require_api_key

logger = logging.getLogger(__name__)


class StartSessionView(APIView):
    """
    Step 1: Mobile app calls this to get a session token.
    Session token ties all subsequent calls together.
    """

    def post(self, request):
        serializer = StartSessionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        session = VerificationSession.objects.create(
            session_token=secrets.token_urlsafe(32),
            api_key=request.auth,
            app_version=serializer.validated_data.get("app_version", ""),
            device_os=serializer.validated_data.get("device_os", ""),
            model_version=serializer.validated_data.get("model_version", "v1.0.0"),
            ip_address=get_client_ip(request),
        )

        return Response({
            "session_token": session.session_token,
            "expires_in": 600,      # 10 minutes to complete verification
        }, status=status.HTTP_201_CREATED)


class UploadVerificationView(APIView):
    """
    Step 2: Mobile uploads document + selfie images.
    Server runs OCR + biometric inference and computes the decision.
    """

    def post(self, request):
        serializer = UploadVerificationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            session = VerificationSession.objects.get(
                session_token=data["session_token"],
                decision=VerificationSession.Decision.PENDING
            )
        except VerificationSession.DoesNotExist:
            return Response({"error": "Invalid or expired session"}, status=404)

        doc_image = data["document_image"]
        selfie_image = data["selfie_image"]

        # Run server-side OCR
        ocr_result = run_ocr_on_document(doc_image)

        # TODO: run face detection + embedding + liveness on server
        # face_similarity, liveness_score, doc_quality_score, field_valid_score = ...

        # Store OCR fields (example)
        session.extracted_name      = ocr_result.get("name", "")
        session.extracted_id_number = ocr_result.get("id_number", "")
        session.extracted_dob       = ocr_result.get("dob")
        session.extracted_expiry    = ocr_result.get("expiry")
        session.ocr_confidence      = ocr_result.get("confidence", 0.0)

        # Decision engine (uses server-computed signals)
        decision_result = make_decision(session)
        session.risk_score   = decision_result["risk_score"]
        session.decision     = decision_result["decision"]
        session.reason_codes = decision_result["reason_codes"]
        session.completed_at = timezone.now()
        session.save()

        if request.auth:
            request.auth.verifications_used += 1
            request.auth.save(update_fields=["verifications_used"])

        log_verification(session)

        return Response({
            "session_id": str(session.id),
            "estimated_wait_ms": 1500
        }, status=status.HTTP_202_ACCEPTED)


class SessionResultView(APIView):
    """Retrieve the result of a completed verification session."""

    def get(self, request, session_id):
        try:
            session = VerificationSession.objects.get(
                id=session_id,
                api_key=request.auth
            )
        except VerificationSession.DoesNotExist:
            return Response({"error": "Not found"}, status=404)

        serializer = VerificationResultSerializer(session)
        return Response(serializer.data)


# --- Admin / Manual Review Views ---

class ReviewQueueView(APIView):
    """List all sessions flagged for manual review."""

    permission_classes = ["rest_framework.permissions.IsAdminUser"]

    def get(self, request):
        sessions = VerificationSession.objects.filter(
            decision=VerificationSession.Decision.MANUAL_REVIEW,
            manual_decision=VerificationSession.ManualDecision.PENDING,
        ).order_by("created_at")[:50]

        return Response([{
            "id":           str(s.id),
            "risk_score":   s.risk_score,
            "reason_codes": s.reason_codes,
            "created_at":   s.created_at.isoformat(),
            "signals": {
                "face_similarity":  s.face_similarity,
                "liveness_score":   s.liveness_score,
                "ocr_confidence":   s.ocr_confidence,
                "doc_quality":      s.doc_quality_score,
            }
        } for s in sessions])


class SubmitReviewView(APIView):
    """Submit a manual review decision."""

    permission_classes = ["rest_framework.permissions.IsAdminUser"]

    def post(self, request, session_id):
        from rest_framework.serializers import Serializer, CharField

        decision = request.data.get("decision")   # "APPROVED" or "REJECTED"
        notes    = request.data.get("notes", "")

        if decision not in ["APPROVED", "REJECTED"]:
            return Response({"error": "Invalid decision"}, status=400)

        try:
            session = VerificationSession.objects.get(id=session_id)
        except VerificationSession.DoesNotExist:
            return Response({"error": "Not found"}, status=404)

        session.manual_decision = decision
        session.reviewer_notes  = notes
        session.reviewed_by     = request.user
        session.reviewed_at     = timezone.now()
        session.save(update_fields=[
            "manual_decision", "reviewer_notes",
            "reviewed_by", "reviewed_at"
        ])

        return Response({"status": "ok", "decision": decision})


class StatsView(APIView):
    """Dashboard stats — useful for thesis demo and startup pitch."""

    permission_classes = ["rest_framework.permissions.IsAdminUser"]

    def get(self, request):
        from django.db.models import Count, Avg

        stats = VerificationSession.objects.aggregate(
            total=Count("id"),
            accepted=Count("id", filter=models.Q(decision="ACCEPT")),
            rejected=Count("id", filter=models.Q(decision="REJECT")),
            manual_review=Count("id", filter=models.Q(decision="MANUAL_REVIEW")),
            avg_risk_score=Avg("risk_score"),
            avg_face_similarity=Avg("face_similarity"),
            avg_liveness=Avg("liveness_score"),
        )

        return Response(stats)


def get_client_ip(request):
    x_forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if x_forwarded:
        return x_forwarded.split(",")[0]
    return request.META.get("REMOTE_ADDR")
```

---

## Step 6 — Services

```python
# apps/verification/services/ocr_service.py

import pytesseract
from PIL import Image
import re
from datetime import datetime
import io

def run_ocr_on_document(image_file) -> dict:
    """
    Server-side OCR using Tesseract (authoritative).
    Returns extracted fields and overall confidence.
    """
    img = Image.open(image_file)

    # Run Tesseract with document-optimized settings
    ocr_data = pytesseract.image_to_data(
        img,
        output_type=pytesseract.Output.DICT,
        config="--psm 6 --oem 3"    # PSM 6: Assume uniform block of text
    )

    # Calculate average confidence (ignore -1 values)
    confidences = [c for c in ocr_data["conf"] if c > 0]
    avg_confidence = sum(confidences) / len(confidences) / 100 if confidences else 0.0

    full_text = pytesseract.image_to_string(img, config="--psm 6 --oem 3")

    return {
        "name":       _extract_name(full_text),
        "id_number":  _extract_id_number(full_text),
        "dob":        _extract_date(full_text, field="dob"),
        "expiry":     _extract_date(full_text, field="expiry"),
        "confidence": round(avg_confidence, 4),
        "raw_text":   full_text,
    }

def _extract_id_number(text):
    # Match common ID patterns: NG-1234-2019, A12345678, etc.
    patterns = [
        r"[A-Z]{2}-\d{4}-\d{4}",
        r"[A-Z]\d{8}",
        r"\d{9,12}",
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group()
    return ""

def _extract_date(text, field="dob"):
    # Look for DD/MM/YYYY or YYYY-MM-DD patterns
    patterns = [
        r"\d{2}/\d{2}/\d{4}",
        r"\d{4}-\d{2}-\d{2}",
        r"\d{2}\.\d{2}\.\d{4}",
    ]
    matches = []
    for pattern in patterns:
        matches.extend(re.findall(pattern, text))

    if len(matches) >= 2:
        return matches[0] if field == "dob" else matches[-1]
    elif len(matches) == 1:
        return matches[0]
    return None

def _extract_name(text):
    lines = [l.strip() for l in text.split("\n") if len(l.strip()) > 3]
    # Heuristic: name is usually one of the longer uppercase lines
    for line in lines:
        if line.isupper() and 5 < len(line) < 60 and re.match(r"^[A-Z\s]+$", line):
            return line.title()
    return ""
```

```python
# apps/verification/services/decision_engine.py

from apps.ml.inference import run_decision_engine

def make_decision(session) -> dict:
    """
    Takes a VerificationSession with all scores populated.
    Returns decision dict.
    """
    signal_vector = session.get_signal_vector()
    return run_decision_engine(signal_vector)
```

---

## Step 7 — Django Admin (Free Manual Review Console)

```python
# apps/verification/admin.py

from django.contrib import admin
from django.utils.html import format_html
from .models import VerificationSession

@admin.register(VerificationSession)
class VerificationSessionAdmin(admin.ModelAdmin):

    list_display = [
        "short_id", "decision_badge", "risk_score_display",
        "face_similarity", "liveness_score", "created_at", "manual_decision"
    ]

    list_filter  = ["decision", "manual_decision", "device_os", "model_version"]
    search_fields = ["session_token", "extracted_name", "extracted_id_number"]
    readonly_fields = [
        "id", "session_token", "created_at", "completed_at",
        "face_similarity", "liveness_score", "ocr_confidence",
        "doc_quality_score", "risk_score", "reason_codes",
        "extracted_name", "extracted_id_number", "extracted_dob",
        "ip_address", "model_version"
    ]

    fieldsets = (
        ("Decision", {
            "fields": ("decision", "risk_score", "reason_codes")
        }),
        ("AI Signals", {
            "fields": (
                "face_similarity", "liveness_score",
                "ocr_confidence", "doc_quality_score", "field_valid_score"
            )
        }),
        ("Extracted Fields", {
            "fields": ("extracted_name", "extracted_id_number", "extracted_dob", "extracted_expiry")
        }),
        ("Manual Review", {
            "fields": ("manual_decision", "reviewer_notes", "reviewed_by", "reviewed_at")
        }),
        ("Metadata", {
            "fields": ("session_token", "model_version", "device_os", "ip_address", "created_at"),
            "classes": ("collapse",)
        }),
    )

    actions = ["bulk_approve", "bulk_reject"]

    def short_id(self, obj):
        return str(obj.id)[:8]
    short_id.short_description = "ID"

    def decision_badge(self, obj):
        colors = {
            "ACCEPT":        "green",
            "REJECT":        "red",
            "MANUAL_REVIEW": "orange",
            "PENDING":       "gray",
        }
        color = colors.get(obj.decision, "gray")
        return format_html(
            '<span style="color:{}; font-weight:bold">{}</span>',
            color, obj.decision
        )
    decision_badge.short_description = "Decision"

    def risk_score_display(self, obj):
        if obj.risk_score is None:
            return "—"
        color = "green" if obj.risk_score < 0.30 else ("red" if obj.risk_score > 0.60 else "orange")
        return format_html(
            '<span style="color:{}">{:.2f}</span>', color, obj.risk_score
        )
    risk_score_display.short_description = "Risk Score"

    def bulk_approve(self, request, queryset):
        from django.utils import timezone
        queryset.update(
            manual_decision="APPROVED",
            reviewed_by=request.user,
            reviewed_at=timezone.now()
        )
    bulk_approve.short_description = "Approve selected sessions"

    def bulk_reject(self, request, queryset):
        from django.utils import timezone
        queryset.update(
            manual_decision="REJECTED",
            reviewed_by=request.user,
            reviewed_at=timezone.now()
        )
    bulk_reject.short_description = "Reject selected sessions"
```

---

## Step 8 — API Key Authentication

```python
# apps/accounts/authentication.py

from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from .models import APIKey

class APIKeyAuthentication(BaseAuthentication):
    """
    Businesses authenticate with: Authorization: ApiKey kyc_xxxxx
    This is your startup's billing gate.
    """

    def authenticate(self, request):
        auth_header = request.META.get("HTTP_AUTHORIZATION", "")

        if not auth_header.startswith("ApiKey "):
            return None  # Try other auth methods

        key = auth_header.split(" ")[1]

        try:
            api_key = APIKey.objects.select_related("owner").get(
                key=key,
                is_active=True
            )
        except APIKey.DoesNotExist:
            raise AuthenticationFailed("Invalid API key")

        if not api_key.is_within_limit:
            raise AuthenticationFailed("Monthly verification limit exceeded")

        return (api_key.owner, api_key)  # (user, auth)
```

---

## Step 9 — URLs

```python
# config/urls.py

from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path("admin/",    admin.site.urls),
    path("api/v1/",   include("apps.verification.urls")),
    path("api/v1/",   include("apps.accounts.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/",   SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]
```

```python
# apps/verification/urls.py

from django.urls import path
from . import views

urlpatterns = [
    path("verify/start/",           views.StartSessionView.as_view()),
    path("verify/upload/",          views.UploadVerificationView.as_view()),
    path("verify/<uuid:session_id>/", views.SessionResultView.as_view()),
    path("verify/history/",         views.VerificationHistoryView.as_view()),
    path("admin/review-queue/",     views.ReviewQueueView.as_view()),
    path("admin/review/<uuid:session_id>/", views.SubmitReviewView.as_view()),
    path("admin/stats/",            views.StatsView.as_view()),
]
```

---

## Step 10 — Docker Setup

```dockerfile
# Dockerfile

FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

```yaml
# docker-compose.yml

version: "3.9"

services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: kyc_db
      POSTGRES_USER: kyc_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build: .
    command: >
      sh -c "python manage.py migrate &&
             python manage.py collectstatic --no-input &&
             gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 4"
    volumes:
      - ./models:/app/models    # mount trained model files here
    ports:
      - "8000:8000"
    env_file:
      - .env
    depends_on:
      - db
      - redis

  celery:
    build: .
    command: celery -A config worker -l info
    env_file:
      - .env
    depends_on:
      - redis
      - backend

volumes:
  postgres_data:
```

```bash
# .env
DJANGO_SECRET_KEY=your-secret-key-here
DB_PASSWORD=your-db-password
DB_HOST=db
REDIS_URL=redis://redis:6379/0
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

---

## Step 11 — Migrations & First Run

```bash
# First time setup
docker-compose up -d db redis
python manage.py makemigrations verification accounts
python manage.py migrate
python manage.py createsuperuser    # for Django admin access

# Run everything
docker-compose up

# Test the API
curl -X POST http://localhost:8000/api/v1/verify/start/ \
  -H "Authorization: ApiKey kyc_yourkey" \
  -H "Content-Type: application/json" \
  -d '{"app_version": "1.0.0", "device_os": "android", "model_version": "v1.0.0"}'

# Upload images (server-authoritative inference)
curl -X POST http://localhost:8000/api/v1/verify/upload/ \
  -H "Authorization: ApiKey kyc_yourkey" \
  -F "session_token=abc123xyz..." \
  -F "document_image=@/path/to/document.jpg" \
  -F "selfie_image=@/path/to/selfie.jpg"
```

---

## API Response Contract (What Flutter Expects)

### POST /api/v1/verify/start/
```json
{
  "session_token": "abc123xyz...",
  "expires_in": 600
}
```

### POST /api/v1/verify/upload/
```json
{
  "session_id": "uuid-here",
  "estimated_wait_ms": 1500
}
```

### GET /api/v1/verify/{session_id}/
```json
{
  "session_id": "uuid-here",
  "decision": "ACCEPT",
  "risk_score": 0.18,
  "reason_codes": [],
  "timestamp": "2025-03-05T14:32:00Z"
}
```

---

## Build Timeline

| Task | Time Estimate |
|---|---|
| Project setup + settings + Docker | 1 day |
| Database models + migrations | 1 day |
| ML model loading (apps.py pattern) | 0.5 day |
| Core API views + serializers | 2 days |
| OCR service + decision service | 1 day |
| Django admin customization | 0.5 day |
| API key authentication | 0.5 day |
| Tests (pytest-django) | 2 days |
| Docker-compose + deployment | 1 day |
| **Total** | **~9–10 days** |

---

*Document 2 of 3 — Next: Document 3: Flutter Mobile App Implementation Plan*
