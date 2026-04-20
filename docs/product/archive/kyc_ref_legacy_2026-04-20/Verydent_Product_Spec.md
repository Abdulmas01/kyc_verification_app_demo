Status: Archived/Deprecated

# VERYDENT Product Specification
## AI-Powered KYC Verification for Emerging Markets
**Version 1.0 · Pre-seed / Thesis-to-Product · 2026**

---

## PART 1 — PRODUCT VISION

### What Verydent Is
Verydent is a KYC-as-a-Service API that enables any digital business to verify the identity of their users in under 5 seconds, from a mobile phone, at a fraction of the cost of existing solutions.

Businesses integrate Verydent's SDK into their mobile app. Their users scan an ID document, take a selfie, and receive an instant verification decision. The business gets a risk score, a decision, and a full audit trail via API.

### The One-Line Pitch
"Stripe-level developer experience for identity verification, built for the African market, at 10× lower cost than Jumio or Onfido."

### The Problem We Solve
Identity verification in Africa is broken in three specific ways:
*   **Cost**: Jumio and Onfido charge $1–5 per verification. A Nigerian fintech doing 50,000 verifications a month pays $50,000–250,000 to verify their own users. This is not viable at African market price points.
*   **Connectivity Dependency**: Existing solutions upload raw document images and selfies to cloud servers for processing. In markets with unreliable mobile data, this produces high failure rates and poor user experience.
*   **Western-First Design**: Document templates, OCR training data, and compliance frameworks are built for US/EU markets. African ID documents are treated as edge cases.

### The Verydent Difference
| Advantage | What It Means |
| :--- | :--- |
| **Server-authoritative hybrid** | Mobile guides capture; server computes final biometric scores. Secure and reproducible without trusting client signals. |
| **African-first documents** | Built for Nigerian NIN, Ghana Card, Kenyan Huduma Namba, SA ID — not retrofitted from a Western baseline. |
| **Cost structure** | Compressed ONNX models on CPU servers — not GPU. Mobile pre-screening reduces unnecessary uploads. 5–20× cheaper than Jumio/Onfido server costs. |

---

## PART 2 — ARCHITECTURE

### Server-Authoritative Hybrid Design
Verydent uses a server-authoritative hybrid architecture. Mobile handles real-time UX feedback and capture guidance. The server handles all biometric inference that feeds the final decision. No client-generated biometric score is trusted for the decision.

This design was chosen deliberately over a fully edge-first alternative. A fully edge-first system introduces an unresolvable payload tampering vulnerability: a technically capable attacker can intercept and fabricate score values before transmission. Moving authoritative inference to the server eliminates this vulnerability entirely.

### Responsibility Split
| Component | Where | Purpose |
| :--- | :--- | :--- |
| Document quality TFLite model | Mobile | Real-time camera UX feedback only — never sent to server |
| ML Kit boundary detection | Mobile | Perspective warp, normalise image before upload |
| ML Kit face detection | Mobile | Confirm face present before capture |
| Active liveness challenges | Mobile (ML Kit) | UX guidance only (blink + head-turn) |
| AES-256-GCM image encryption | Mobile | Secure images before upload |
| ECDSA payload signing | Mobile (TEE) | Attest payload origin and integrity |
| Play Integrity token | Mobile | Attest device and app authenticity |
| Document quality (authoritative) | Server (ONNX) | Quality score that feeds decision engine |
| OCR + field extraction | Server | Tesseract + MRZ (authoritative), ML Kit optional UX pre-fill |
| Face embedding + similarity | Server (ONNX) | Authoritative face match score |
| Passive liveness scoring | Server (ONNX) | Authoritative liveness score |
| Decision engine | Server (XGBoost) | P(genuine) → ACCEPT / REVIEW / REJECT |

### Security Model & Enhancements
Because the server computes all authoritative inference from raw encrypted images, there are no client-generated scores to fabricate. Two core controls protect what the mobile device sends:
1.  **ECDSA Payload Signing** — signed with private key in Android Hardware-Backed Keystore (TEE). Key cannot be extracted even from a rooted device. Modified payloads are rejected.
2.  **Android Play Integrity API** — every request verified with Google. Rooted devices, emulators, and modified APKs are rejected before any inference runs.

**Recognised Security Out-of-Scope (Future Work):**
*   **Idempotency / Replay Attack Mitigation**: While the system defends against biometric spoofing, mitigating API-level replay attacks (e.g., submitting the exact same image hash multiple times) is considered an infrastructure networking concern and is out of scope for this biometric evaluation.
*   **Coupled Biometric Thresholds**: The decision engine currently aggregates signals independently. Applying dynamic penalty thresholds (e.g., raising required face similarity if the liveness score is borderline) is acknowledged as a viable security hardening technique but is left for future work.

| Attack Vector | Response |
| :--- | :--- |
| Proxy interception + payload modification | ECDSA signature fails → rejected |
| Fabricated biometric scores | No client scores trusted — server computes all scores from raw images |
| Rooted device | Play Integrity fails → rejected |
| Modified APK | Play Integrity fails → rejected |
| Photo / print attack | Passive liveness model (server) + active challenge UX helps capture |
| Deepfake video replay | Passive liveness baseline; advanced deepfake defense is future work |
| Scripted replay attack | **Idempotency hash check drops duplicate images instantly** |

---

## PART 3 — SYSTEM LIMITATIONS & FUTURE WORK

As a Master's thesis, explicit boundaries constrain the scope of the implemented system. The following limitations are acknowledged and designated as future work:

### 1. The Synthetic-to-Real Domain Gap
The Document Quality model utilizes a synthetically generated dataset. While augmented for robustness, the system will experience an accuracy degradation when encountering real-world physical damage specific to aging identification cards (e.g., severe fading, peeling lamination). Closing this domain gap via real-world data collection is out of scope.

### 2. Deepfake and Generative AI Attacks
The implemented liveness detection mechanism targets traditional presentation attacks (printed photos and screen replays). Detecting highly sophisticated, real-time deepfake video streams or Generative AI injections falls outside the scope of this project and requires dedicated forensic modelling (e.g., StyleGAN artifact detection), which is left as future work.

### 3. Document Forgery and Layout Analysis
The system performs biometric matching and data extraction. However, it does not perform structural or geometric layout analysis to authenticate the physical document itself against an official template using LayoutLM or similar techniques. Detecting high-quality document forgeries is therefore an acknowledged limitation.

### 4. Database Verification (Source of Truth)
The verification pipeline is strictly biometric and document-based. It confirms that the individual in the selfie matches the presented ID card. Integration with external national identity databases (e.g., NIMC) to verify the legal existence of the extracted credentials is out of scope.

### 5. Hardware Dependency 
Active liveness features assume moderate device capabilities. The performance variance on extremely low-end or obsolete mobile hardware (which may fail to meet the frame-rate requirements for active capture) is acknowledged but not actively benchmarked in this study.

### 6. Facial Alignment on Degraded Crops
If the extracted face crop from the ID card is excessively degraded, the facial landmark aligner may fail. This results in the embedding of unaligned faces, which inherently lowers the cosine similarity score and increases the False Rejection Rate (FRR). Improving landmark detection resilience on low-resolution prints is left for future optimization.

---

## PART 4 — PRICING

### Pricing Tiers
Predictable costs for customers. Predictable revenue for Verydent. Low friction entry. Natural upgrade path.

| Tier | Price | Included | Overage | Target |
| :--- | :--- | :--- | :--- | :--- |
| **Free Developer** | $0/month | 50 verifications | — | Developer evaluation |
| **Starter** | $49/month | 200 verifications | $0.30 each | Early-stage startups, pilots |
| **Growth** | $199/month | 1,000 verifications | $0.22 each | Growing fintechs |
| **Scale** | $599/month | 5,000 verifications | $0.15 each | Established platforms |
| **Enterprise** | Custom | Unlimited | Negotiated | Banks, large exchanges |

Annual prepay available at 20% discount. Default option shown during onboarding. African businesses often have annual budget cycles — this matches how they buy.

### Unit Economics
| Tier | Revenue/verification | Server cost/verification | Gross Margin |
| :--- | :--- | :--- | :--- |
| **Starter** | $0.245 | $0.065 | ~73% |
| **Growth** | $0.199 | $0.055 | ~72% |
| **Scale** | $0.120 | $0.045 | ~63% |
| **Enterprise**| $0.080 | $0.035 | ~56% |

Server inference uses INT8-quantised ONNX models on CPU — not large models on GPU instances. The compression study is directly responsible for the cost advantage: Jumio/Onfido server costs are $0.30–0.80 per verification. Verydent is $0.04–0.07.

---

## PART 5 — GO TO MARKET

### Target Customer
**Primary: African Fintechs and Neobanks**
Digital financial services companies in Nigeria, Ghana, Kenya, South Africa operating under CBN, Bank of Ghana, CBK, or SARB regulation. KYC is a legal requirement for them — they are already spending money on this problem.

Who specifically to target first:
- Neobanks doing 1,000–50,000 onboardings per month
- Lending platforms (BNPL, personal loans) — high verification volume
- Crypto exchanges operating in Africa — strong KYC requirements

### Competitive Positioning
| | Verydent | Smile Identity | Jumio | Onfido |
| :--- | :--- | :--- | :--- | :--- |
| **Price/verification** | $0.15–0.30 | $0.50–1.50 | $1–3 | $1–5 |
| **African document support** | ✅ Native | ✅ Good | ⚠️ Limited | ⚠️ Limited |
| **On-device pre-screening (UX)**| ✅ Quality + challenges | ❌ | ❌ | ❌ |
| **Low-bandwidth optimised** | ✅ Small encrypted upload| ❌ | ❌ | ❌ |
| **Developer self-serve** | ✅ Instant | ⚠️ Sales call | ❌ Sales call | ❌ Sales call |
| **Free tier** | ✅ | ❌ | ❌ | ❌ |

### Sales Motion
*   **Phase 1 — Developer-Led Growth (Month 1–6):** The free tier is the sales team. Developer finds Verydent → creates account instantly → integrates SDK in 1–2 days → shows CTO → company upgrades to paid plan. Zero sales effort required.
*   **Phase 2 — Direct Outreach to Fintechs (Month 3–9):** Once 10–20 companies are on paid plans, use them as references. Target companies currently using Smile Identity, Appruve, or manual KYC — they already have budget allocated for this line item.
*   **Phase 3 — Partnership Channel (Month 6–18):** Partner with fintech-focused dev agencies, core banking system vendors, and pan-African accelerator portfolios. One agency partnership can produce 5–10 paying customers without direct sales.

---

## PART 6 — PRODUCT ROADMAP

| Version | Timeline | Focus | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **v1.0 — Thesis MVP** | Month 1–5 | Working demo | Flutter SDK, 3 TFLite models, Django backend, decision engine, admin console |
| **v1.1 — Security** | Month 6–7 | Commercial ready | Play Integrity, hardware signing, server-side verification for borderline cases |
| **v1.2 — Documents** | Month 7–9 | Market coverage | NIN, Ghana Card, Huduma Namba, SA ID, Voter Card full support |
| **v2.0 — SDK Expansion** | Month 9–12| Reach | React Native SDK, Web SDK, analytics dashboard |
| **v2.1 — Enterprise** | Month 12–18| Revenue quality | White-label, on-premise, compliance exports, SLA monitoring |
| **v3.0 — Data Flywheel** | Month 18+ | Moat | Retrain on real data, active learning, fairness monitoring in production |

The data flywheel is the long-term moat. Every real verification session improves the next model version. Competitors cannot replicate this without the same data volume.

---

## PART 7 — INFRASTRUCTURE AND FUNDING

### Infrastructure
| Component | Technology | Hosting |
| :--- | :--- | :--- |
| Backend API | Django 5.0 + DRF | Railway.app or Render.com |
| Database | PostgreSQL 16 | Managed (Railway / Supabase) |
| Task Queue | Celery + Redis | Same platform |
| Server Models | ONNX Runtime | Same server |
| SDK Models | TFLite (bundled) | Client device (free) |
| CDN / Static | Cloudflare | Free tier |

Infrastructure cost at launch: ~$50/month. Profitable from the first Starter plan customer. This is the advantage of server-authoritative CPU inference — no GPU servers, no cloud OCR API costs.

### Funding Milestones
| Phase | Timeline | Target | Goal |
| :--- | :--- | :--- | :--- |
| **Thesis Phase** | Now → Month 5 | $0 (self-funded) | 10 paying customers, $490 MRR, working demo |
| **Pre-seed raise**| Month 5–8 | $150K–250K | Legal setup, security audit, 6 months runway |
| **Seed round** | Month 12–18| $1M–2M | $10K+ MRR, 50+ customers, 3+ countries |

**Pre-Seed Pitch Narrative:**
"We built the AI during our master's thesis. We have a working product, 10 paying customers, and $490 MRR after 5 months. The KYC market in Africa is $500M and growing. We are 10× cheaper than Smile Identity with better technology. We need $200K to reach $10K MRR and raise a seed round."

---

## PART 8 — RELATIONSHIP TO THESIS

### Thesis vs Product
| Aspect | Thesis | Verydent Product |
| :--- | :--- | :--- |
| **Primary goal** | Academic contribution | Commercial revenue |
| **Dataset licensing** | Any (CASIA-FASD for eval) | Commercial only (CelebA-Spoof) |
| **Security implementation**| Documented, partial | Fully implemented (v1.1) |
| **Document scope** | Synthetic + limited real | Full African document coverage |
| **Decision engine data** | Simulated sessions | Real session history |
| **Compliance** | Not required | Required before first customer |

### What Transfers Directly From Thesis to Product
*   All trained TFLite models (trained on commercially licensed data)
*   Django backend codebase — complete reuse
*   Flutter SDK codebase — complete reuse
*   Compression study results — validates production model choices
*   Decision engine — retrain on real data over time

### What Needs to Be Built Post-Thesis
*   Play Integrity API integration and hardware-backed signing (v1.1)
*   African document template library (v1.2)
*   Billing integration — Paystack for African customers
*   Developer documentation site
*   Legal and compliance setup — NDPC registration, DPA templates, ToS
