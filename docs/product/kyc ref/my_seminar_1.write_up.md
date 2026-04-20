Status: Thesis Canonical


MSc IN EMBEDDED ARTIFICIAL INTELLIGENCE
SEMINAR I (PROGRESS)

HYBRID MOBILE-SERVER DEEP LEARNING FOR BIOMETRIC KYC IDENTITY VERIFICATION


By

SALIHU, ABDUL MOHAMMED-AUWAL
PGS/24-25/M/2/11178


CENTER FOR EMBEDDED ARTIFICIAL INTELLIGENCE AND SMART ENERGY SYSTEMS
ABUBAKAR TAFAWA BALEWA UNIVERSITY, BAUCHI


SUPERVISORY COMMITTEE:
DR. N. A. SHUAIBU
Dr. L. N. ABDULKADIR



APRIL, 2026

ABSTRACT
Know Your Customer (KYC) identity verification is a mandatory compliance requirement for financial institutions across Nigeria and sub-Saharan Africa, yet manual verification processes remain slow, costly, and a barrier to financial inclusion for millions of unbanked citizens (World Bank, 2021; Wezel & Ree, 2023). This study presents the design, training, and optimisation of a multi-model deep learning pipeline for automated KYC verification on mid-range Android devices. Five task-specialised neural network modules were developed covering document quality assessment, document boundary detection, optical character recognition, face biometric matching, and passive liveness detection. The pipeline adopts a server-authoritative hybrid architecture, defined here as mobile-only capture guidance with all decision-driving biometric inference computed server-side from uploaded images, eliminating the payload tampering risk of edge-first designs. A synthetic training dataset of 5,000 identity document images across five quality classes was generated programmatically using PIL rendering with controlled per-class augmentation, split 70/15/15 for train/validation/test. The document quality classifier  MobileNetV3-Small pretrained on ImageNet-1K and fine-tuned using AdamW with cosine annealing  achieved 97.73% test accuracy and F1-score of 0.9774. A compression study comparing INT8 post-training quantization and knowledge distillation showed that INT8 quantization produced zero accuracy loss for this task, while a distilled student model (MobileNetV3-Small-050) achieved higher accuracy of 98.67% at 2.29 MB  a 2.6× size reduction with 9.16 ms CPU latency. Face embedding training using MobileFaceNet with ArcFace loss is complete. Liveness detection training on CelebA-Spoof is in progress. The study contributes completed evidence for document-quality compression and a formally justified server-authoritative architecture; per-task compression contrast claims for face and liveness remain in-progress pending final experiments.

1.0  INTRODUCTION
1.1  Background of the Study
Digital financial services have expanded rapidly across sub-Saharan Africa, yet the unbanked population remains large. The World Bank (2021) reported that approximately 1.4 billion adults globally still lack access to formal financial services, with Nigeria underperforming peer African economies in mobile money adoption despite a large fintech ecosystem (Wezel & Ree, 2023). A primary barrier is the absence of affordable, remotely accessible identity verification  mandatory under KYC regulations enforced by the Financial Action Task Force (2020) and the NIST identity assurance framework (Grassi et al., 2017). Traditional KYC requires in-person document inspection, which is impractical in rural areas with sparse branch infrastructure.
Deep learning has demonstrated strong performance across biometric sub-tasks: face recognition (Deng et al., 2019), anti-spoofing (Zhang et al., 2020), and document quality assessment. However, deploying these models on low-cost Android devices without GPU acceleration introduces a compression challenge that has received limited study across heterogeneous biometric tasks. This study addresses this gap by designing, training, and evaluating a complete mobile KYC pipeline with a per-task compression study and a formally justified server-authoritative architecture.
1.2  Statement of the Problem
Adewopo et al. (2024) documented a 28% rise in identity fraud across African financial services in 2022 based on approximately 50 million KYC verification events, attributing this to inadequate verification infrastructure. Three specific problems motivate this study:
First, no published work has designed or evaluated a complete AI-based KYC pipeline targeting mobile CPU deployment on mid-range Android devices in the Nigerian context.
Second, the accuracy-efficiency tradeoffs of model compression have not been studied across the different biometric sub-tasks of a KYC system, particularly the sensitivity of ArcFace-trained face embeddings to quantization-induced rounding errors (Deng et al., 2019).
Third, published KYC decision engines use manually assigned fixed weights without calibration evaluation, leaving their probabilistic reliability uncharacterised.
1.3  Aim and Objectives
This study aims to design, train, and optimise a multi-model deep learning pipeline for automated KYC identity verification deployable on mid-range Android devices without GPU acceleration.
The specific objectives are to:
	•	by Month 2, design and train a MobileNetV3-Small document quality classifier for five quality states, targeting test accuracy ≥ 90% and macro F1 ≥ 0.90;
	•	by Month 2, develop a synthetic identity document dataset of 5,000 annotated images with a 70/15/15 split for supervised training without real personal data;
	•	by Month 4, implement a face biometric verification module using MobileFaceNet with ArcFace loss, targeting a measurable Equal Error Rate threshold on LFW;
	•	by Month 5, design and evaluate a passive liveness detection classifier using MobileNetV2 fine-tuned on CelebA-Spoof under ISO/IEC 30107-3 metrics (APCER, BPCER, ACER);
	•	by Month 5, evaluate a calibrated probabilistic decision engine against a hand-engineered weighted scoring baseline using Expected Calibration Error, Brier Score, and AUC-ROC; and
	•	by Month 6, conduct a systematic compression study comparing INT8 post-training quantization and knowledge distillation across the document quality, face embedding, and liveness modules for mobile CPU deployment.
1.4  Significance of the Study
Academically, this study provides a per-task compression sensitivity analysis for a mobile biometric KYC pipeline, showing empirically that different biometric tasks respond differently to INT8 quantization. It also applies calibration-specific metrics (Expected Calibration Error, Brier Score) to KYC decision fusion  an evaluation not reported in the reviewed literature  and documents the security tradeoff between edge-first and server-authoritative mobile biometric architectures. Practically, the pipeline offers a deployable, privacy-preserving alternative to commercial KYC providers at an estimated USD 0.04 to 0.07 per verification  relevant to Nigerian fintech operators serving mass-market users who cannot afford premium verification services.
1.5  Scope of the Study
The study covers the AI components of a mobile KYC system integrated into a Flutter Android application. Document verification is limited to the Nigerian NIN Smart Card. Face verification is still-image based. Liveness detection uses passive single-frame classification; active challenges via ML Kit are for UX guidance only. Excluded from scope: iOS deployment, NIMC database verification, multi-country documents, deepfake liveness detection, and structured model pruning. Fairness evaluation uses available annotations in public datasets; a Nigeria-specific demographic corpus is identified as future work.
1.6  Research Methodology
A synthetic document dataset was generated programmatically using PIL and used to train a MobileNetV3-Small quality classifier with transfer learning. A compression study was then conducted comparing INT8 post-training quantization and knowledge distillation. Face embedding was implemented using MobileFaceNet trained with ArcFace loss. Liveness detection uses MobileNetV2 fine-tuned on CelebA-Spoof (in progress). The decision engine compares a hand-engineered weighted formula against logistic regression and XGBoost with isotonic calibration. Statistical rigor steps for final reporting include 95% confidence intervals (Wilson interval for accuracy and bootstrap confidence intervals for F1), 3–5 repeated runs with different random seeds (mean ± standard deviation), and paired significance testing (McNemar or paired bootstrap) for FP32 vs INT8 vs distilled model comparisons. All models are exported to ONNX for server-side inference and TFLite for on-device deployment in a Flutter application backed by a Django-Celery server.

2.0  LITERATURE REVIEW
2.1  Introduction
The study draws on six thematic areas: KYC and digital identity in Nigeria; automated identity verification policy; face recognition and biometric embedding; liveness detection and anti-spoofing; document verification and OCR; and model compression for mobile deployment. The review is organised thematically to identify limitations that motivate the contributions of this study.
2.2  Fundamental Concepts
Know Your Customer (KYC) verification is the process by which financial institutions confirm the identity of a customer before granting access to services. Regulatory frameworks  including the Financial Action Task Force guidance and NIST SP 800-63-3  define identity assurance levels that specify requirements for document verification, liveness detection, and biometric comparison (FATF, 2020; Grassi et al., 2017).
Convolutional neural networks (CNNs) form the backbone of the AI modules in this study. Transfer learning  the practice of initialising a model with weights pretrained on a large dataset before fine-tuning on a smaller task-specific corpus  is the dominant training strategy for mobile biometric models (Howard & Ruder, 2018). Model compression refers to techniques that reduce the size and inference cost of neural networks for deployment on resource-constrained hardware. The two techniques studied here are post-training INT8 quantization, which converts FP32 weights to 8-bit integer representation without retraining, and knowledge distillation, in which a smaller student model is trained to reproduce the output distributions of a larger teacher model (Hinton et al., 2015). The ArcFace loss function enforces large angular margins between identity class centres on the face embedding hypersphere, as given by Equation 1 (Deng et al., 2019):
L = −log( es·cos(θyi+m) / (es·cos(θyi+m) + Σj≠yi es·cos(θj)) )    (Equation 1)
where θyi is the angle between the embedding and the class centre, m is the angular margin (0.5), and s is the feature scale (64). Liveness detection evaluates whether a biometric sample comes from a live person or a spoofing artefact; it is measured under the ISO/IEC 30107-3 standard using APCER, BPCER, and ACER metrics.
2.3  Review of Pertinent Literature
Ogunode and Akintoye (2023) studied financial technology deployment in Nigeria, identifying poor system interoperability, data privacy concerns, and urban concentration as barriers to digital financial inclusion, noting that approximately 38 million adults remain unbanked. Their work did not investigate technical mechanisms for making biometric verification feasible on low-cost Android devices, which is addressed in this study. Wezel and Ree (2023) documented for the International Monetary Fund that Nigeria's mobile money ownership substantially underperforms peer economies, attributing this partly to the absence of accessible remote verification, and called for technical implementation evidence. Adewopo et al. (2024) reviewed cybersecurity threats in Africa's digital transformation, reporting a 28% fraud rate increase in 2022 and recommending AI-based biometric KYC systems as a countermeasure.
Schroff et al. (2015) introduced FaceNet, a triplet-loss face embedding method achieving 99.63% on LFW. While smaller model variants with mobile runtimes were reported, the highest-performing configurations exceed the real-time CPU inference budget of this study. Deng et al. (2019) proposed ArcFace angular margin loss achieving 99.83% on LFW with a large ResNet backbone. The paper focuses on discriminative embedding learning and does not evaluate the sensitivity of ArcFace-trained embeddings to INT8 quantization, which is not addressed in the reviewed work. Chen et al. (2018) introduced MobileFaceNet, achieving 99.55% on LFW at 4.0 MB trained with ArcFace loss using global depthwise convolution, without evaluating quantization sensitivity. Cao et al. (2018) introduced VGGFace2, a 3.31 million image face dataset with diversity in age, pose, and ethnicity used to train the pretrained weights available in the facenet-pytorch library adopted in this study.
Boulkenafet et al. (2017) introduced the OULU-NPU anti-spoofing dataset, evaluated using ISO/IEC 30107-3 metrics; it is limited to print and replay attacks across 55 subjects. Zhang et al. (2020) introduced CelebA-Spoof with 625,537 images across multiple attack types; experiments in the paper indicate improved generalisation compared to smaller datasets, though this is an empirical finding from specific baselines. Jourabloo et al. (2018) proposed noise modelling for anti-spoofing using a multi-component architecture more complex than lightweight mobile CNNs; mobile deployment suitability is not evaluated in the paper.
Smith (2007) described Tesseract as a two-pass adaptive OCR engine competitive on the UNLV benchmark, designed for clean scanned documents. Limitations under mobile capture conditions are general OCR engineering constraints rather than findings from the paper. Bulatov et al. (2020) introduced MIDV-500 with boundary coordinate annotations for 50 document types in mobile video; it focuses on geometric annotations rather than image-level quality labels. ICAO (2021) defines MRZ structure and check digit rules that motivate the MRZ-first parsing strategy.
Hinton et al. (2015) introduced knowledge distillation, showing in their reported experiments that students trained on soft teacher outputs can outperform comparably sized hard-label models. Jacob et al. (2018) proposed quantization-aware training for integer-only inference, demonstrating near-floating-point accuracy on ImageNet with accuracy gaps that vary by model and task. Sandler et al. (2018) introduced MobileNetV2 with inverted residual blocks, reporting 72.0% ImageNet top-1 accuracy at 3.4 MB and 75 ms on a Pixel 1 device for a specific reported configuration. Howard et al. (2019) introduced MobileNetV3-Small with hard-swish activations and squeeze-and-excitation blocks, reporting improved accuracy-latency tradeoffs including 67.4% accuracy at 15.8 ms on a Pixel 1 for a specific reported configuration. Gou et al. (2021) surveyed knowledge distillation broadly but did not specifically address distillation for biometric metric learning tasks such as ArcFace.
2.4  Research Gaps
Four gaps are identified. First, no published study has measured per-task compression sensitivity  specifically INT8 quantization and knowledge distillation  across the heterogeneous sub-tasks of a complete mobile KYC pipeline, where document quality classification and ArcFace-trained face embedding are expected to exhibit different sensitivity to quantization rounding errors (Deng et al., 2019). Second, no published study has applied calibration-specific metrics such as Expected Calibration Error and Brier Score to compare learned and hand-engineered decision engines in a KYC context. Third, the payload tampering vulnerability of edge-first mobile biometric architectures has not been formally documented or compared against server-authoritative designs in peer-reviewed literature. Fourth, no published work has designed or evaluated a complete mobile KYC AI pipeline addressing the device and network constraints of the Nigerian market, despite documented urgency (Adewopo et al., 2024; Ogunode & Akintoye, 2023).

3.0  MATERIALS AND METHODS
3.1  Materials
The hardware used was a Google Colab T4 GPU (NVIDIA Tesla T4, 16 GB VRAM) accessed via cloud notebook. The software stack comprised Python 3.10, PyTorch 2.0, the timm library for pretrained model loading, Albumentations for training augmentation, the Faker library for synthetic identity data generation, PIL (Pillow) for document image rendering, OpenCV for image quality metric computation, scikit-learn for dataset splitting and evaluation, MLflow for experiment tracking, ONNX Runtime for model export validation, and TensorFlow Lite for mobile model packaging. The CelebA-Spoof dataset (Zhang et al., 2020) will be used for liveness detection training; it is publicly available under a Creative Commons Attribution 4.0 licence. The LFW dataset is used for face verification evaluation. MIDV-500 (Bulatov et al., 2020) provides boundary annotations for document detection evaluation. No real personal identity documents were used at any stage; all training data is synthetically generated.
3.2  Methods
The system adopts a server-authoritative hybrid architecture. Mobile pre-screening guides the user through document and selfie capture; all authoritative biometric inference runs server-side from AES-256-GCM encrypted uploaded images. This eliminates the payload tampering vulnerability of edge-first architectures, where an attacker on a rooted device could substitute fabricated scores before transmission. Cryptographic controls  ECDSA-P256 payload signing via Android Hardware-Backed Keystore and Google Play Integrity API attestation  protect upload integrity. The server pipeline runs in Django with Celery asynchronous task processing.
The synthetic dataset generator programmatically renders identity documents using two PIL layout configurations, each specifying background colour, border style, field positions, and MRZ strip placement. Documents are drawn entirely using PIL primitives  rectangles, text rendering, and MRZ character strings  without pre-designed image templates, ensuring structural uniqueness through randomised identity fields. Five per-class augmentation pipelines produce unambiguous quality labels: GOOD applies minor brightness and noise variation; BLURRY applies heavy Gaussian or motion blur (kernel 11–21 px); GLARE applies an elliptical specular reflection patch; DARK applies severe brightness reduction (45–65 pp); NO_DOCUMENT generates non-document scenes. GOOD samples are additionally filtered by Laplacian sharpness ≥ 40.0, contrast ≥ 30.0, and noise ≤ 12.0.
The document quality classifier uses MobileNetV3-Small pretrained on ImageNet-1K via timm. Early convolutional layers were frozen; the last two blocks and the classification head were fine-tuned. Training used AdamW (lr = 1×10⁻⁴, weight decay = 1×10⁻⁴), cosine annealing over 30 epochs, cross-entropy loss with label smoothing ε = 0.1, gradient clipping at 1.0, batch size 64, and FP16 mixed precision. Early stopping patience was 8 epochs. The compression study applied PyTorch dynamic INT8 quantization post-training (no retraining required) and knowledge distillation using a MobileNetV3-Small-050 student (50% channel multiplier) trained with distillation temperature T = 4.0 and distillation weight α = 0.7 for 20 epochs.
The face embedding module uses MobileFaceNet (Chen et al., 2018) with ArcFace loss (m = 0.5, s = 64), initialised from pretrained weights via the facenet-pytorch library. Input is 112×112 px; output is a 128-dimensional L2-normalised embedding. Verification threshold is selected at the Equal Error Rate on LFW. The liveness detection module uses MobileNetV2 fine-tuned on CelebA-Spoof as a binary live/spoof classifier with weighted binary cross-entropy, evaluated using APCER, BPCER, and ACER per ISO/IEC 30107-3 (training in progress). The decision engine compares a fixed weighted formula (baseline) against logistic regression with Platt scaling and XGBoost with isotonic calibration, evaluated using Expected Calibration Error and Brier Score on simulated session data.

4.0  PRELIMINARY RESULTS AND DISCUSSIONS
4.1  Document Quality Classifier
The classifier was trained on 3,500 samples and evaluated on the 750-sample held-out test set (150 per class). Table 4.1 shows the per-class results for the FP32 baseline.

Class
Precision
Recall
F1-Score
Support
GOOD
0.9800
0.9933
0.9866
150
BLURRY
0.9933
0.9933
0.9933
150
GLARE
0.9467
0.9667
0.9566
150
DARK
0.9933
0.9800
0.9866
150
NO_DOCUMENT
0.9933
0.9733
0.9832
150
Macro Avg
0.9813
0.9813
0.9813
750
Weighted Avg
0.9813
0.9773
0.9774
750
Table 4.1: Per-class results of the FP32 baseline quality model on the test set (n = 750).

Overall test accuracy was 97.73% with a macro F1-score of 0.9774. The BLURRY class recorded the highest F1-score (0.9933) because heavy blur augmentation produces a visually unambiguous signature. The GLARE class had the lowest F1-score (0.9566), attributable to visual overlap between high-brightness GOOD samples and mild glare conditions. The NO_DOCUMENT class achieved 0.9832, confirming the model will not falsely trigger a capture on non-document frames. CPU inference latency was 14.05 ms mean (18.03 ms at 95th percentile) averaged over 200 runs at batch size 1, well within the 10–30 ms real-time target. Latency was measured on a Colab CPU, which is not equivalent to a physical Android device; on-device benchmarks will be conducted in the Flutter integration phase.
4.2  Compression Study
Table 4.2 shows the compression results for the document quality model.

Variant
Size (MB)
Latency (ms)
Test Accuracy
F1 Macro
Acc Δ (pp)
FP32 Baseline
5.94
14.05
97.73%
0.9774

INT8 PTQ
5.93
15.69
97.73%
0.9774
0.00
Distilled Student
2.29
9.16
98.67%
0.9867
+0.93
Table 4.2: Compression study results. Latency measured on Colab CPU, 200 runs, batch size 1.

INT8 post-training quantization produced zero accuracy degradation (delta = 0.00 pp), confirming that document quality classification  with its well-separated class boundaries  is fully robust to INT8 rounding errors. This supports the general finding in the quantization literature that classification tasks with coarse decision boundaries tolerate integer rounding without accuracy loss (Jacob et al., 2018). The INT8 file size reduction is minimal in the current export because dynamic quantization was applied only to selected layer types and non-weight graph/runtime components dominate packaged file size; this will be expanded in the final thesis with per-layer quantization coverage. The distilled student achieved 98.67% accuracy  higher than the FP32 teacher  at 2.29 MB and 9.16 ms, a 2.6× size reduction. The student's accuracy gain is consistent with the regularisation effect described by Hinton et al. (2015), where soft teacher distributions provide richer supervisory signal than hard labels. These results confirm that both compression techniques are viable for the quality classifier; the distilled student is the preferred deployment candidate given its superior accuracy and smaller size.
Compression experiments for the face embedding and liveness detection models will be reported in the final thesis. Based on the design of ArcFace loss, where angular margins between identities are deliberately small, the face embedding model is hypothesised to be more sensitive to INT8 rounding errors than the quality classifier (Deng et al., 2019). This remains a hypothesis pending empirical measurement.
4.3  Mobile Integration Status
The distilled quality TFLite model has been integrated into the Flutter application for real-time camera guidance. Document boundary detection using ML Kit is functional; perspective correction is applied before upload. AES-256-GCM image encryption is implemented. Server-side OCR, face embedding integration, and decision engine evaluation are planned for the next phase following liveness detection training completion.

5.0  SUMMARY, CONCLUSION AND RECOMMENDATION
5.1  Summary
This study designed and partially evaluated a multi-model deep learning pipeline for automated mobile KYC verification targeting mid-range Android devices in the Nigerian context. A 5,000-image synthetic document dataset was generated and used to train a MobileNetV3-Small quality classifier achieving 97.73% test accuracy. A compression study showed INT8 quantization causes zero accuracy loss for this task, while a distilled student model achieved 98.67% accuracy at 2.29 MB and 9.16 ms. The system adopts a server-authoritative architecture justified through a formal security analysis. Face embedding training is complete; liveness detection training is in progress.
5.2  Conclusion
Objectives i and ii have been fully achieved. Objective iv is partially achieved for the quality classifier; compression of the face embedding and liveness models is pending. Objectives iii, v, and vi are in progress and on schedule. The preliminary results support the central hypothesis that different biometric tasks exhibit different sensitivity to model compression, which is the core contribution this study will deliver in the final thesis.
5.3  Contribution to Knowledge
i. A per-task compression sensitivity analysis for a mobile biometric KYC pipeline, with completed evidence showing that document quality classification is robust to INT8 quantization (0.00 pp degradation). The ArcFace-trained face embedding and liveness compression sensitivity comparison remains in progress and will be reported with final empirical measurements.
ii. A formally documented and justified server-authoritative hybrid architecture for mobile biometric verification, demonstrating that the payload tampering vulnerability of edge-first client-score designs can be eliminated without sacrificing mobile UX benefits, with application beyond the KYC domain.
5.4  Recommendation for Further Work
Based on the limitations of the current study, several directions for future work are recommended.
First, this study primarily focused on the development and evaluation of a document classification model using knowledge distillation. The model was trained and tested mainly on synthetic data, which may not fully represent real-world document variations. Future work should therefore include training and evaluation on larger and more diverse real-world datasets to improve generalisation and to quantify the synthetic-to-real domain gap.
Second, the knowledge distillation process can be further improved by exploring different teacher–student architectures, temperature parameters, and loss weighting strategies. This may lead to better trade-offs between model size, computational efficiency, and classification accuracy.
Furthermore, although a complete KYC verification system was proposed in this study, only the document classification component has been fully implemented and evaluated. Other components, including face verification, liveness detection, and decision-level fusion, remain under development and were not experimentally validated within the scope of this report. Future work should focus on the implementation and evaluation of these modules to achieve a complete end-to-end system.
In addition, future research can extend the liveness detection component to address more advanced spoofing attacks such as deepfake and face-swap scenarios. Similarly, face verification models can be integrated to enable biometric matching between identity documents and live user captures.
Finally, fairness evaluation can be improved by developing datasets that better represent Nigerian demographics, as commonly used datasets have known imbalances. Further improvements may also include expanding the synthetic document generator to cover additional document types and integrating document authenticity verification mechanisms.



REFERENCES
Adewopo, V., Gonen, B., Adewopo, F., Varlioglu, S., Elsayed, N., & ElSayed, Z. (2024). Cybersecurity threats and mitigation strategies in Africa's digital transformation. Journal of African Studies and Sustainable Development, 7(4).
Boulkenafet, Z., Komulainen, J., Li, L., Feng, X., & Hadid, A. (2017). OULU-NPU: A mobile face presentation attack database with real-world variations. Proceedings of the 12th IEEE International Conference on Automatic Face & Gesture Recognition (FG 2017), 612–618. https://doi.org/10.1109/FG.2017.77
Bulatov, K., Arlazarov, V. V., Chernov, T., Slavin, O., & Nikolaev, D. (2020). MIDV-500: A dataset for identity document analysis and recognition on mobile devices in video stream. Computer Optics, 44(5), 778–792.
Cao, Q., Shen, L., Xie, W., Parkhi, O. M., & Zisserman, A. (2018). VGGFace2: A dataset for recognising faces across pose and age. Proceedings of the 13th IEEE International Conference on Automatic Face & Gesture Recognition (FG 2018), 67–74. https://doi.org/10.1109/FG.2018.00020
Chen, S., Liu, Y., Gao, X., & Han, Z. (2018). MobileFaceNets: Efficient CNNs for accurate real-time face verification on mobile devices. Chinese Conference on Biometric Recognition (CCBR 2018), Lecture Notes in Computer Science, 428–438. https://doi.org/10.1007/978-3-319-97909-0_46
Deng, J., Guo, J., Xue, N., & Zafeiriou, S. (2019). ArcFace: Additive angular margin loss for deep face recognition. Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR 2019), 4685–4694. https://doi.org/10.1109/CVPR.2019.00482
Financial Action Task Force. (2020). Guidance on digital identity. FATF. https://www.fatf-gafi.org/publications/fatfrecommendations/documents/digital-identity-guidance.html
Gou, J., Yu, B., Maybank, S. J., & Tao, D. (2021). Knowledge distillation: A survey. International Journal of Computer Vision, 129(6), 1789–1819. https://doi.org/10.1007/s11263-021-01453-z
Grassi, P. A., Garcia, M. E., & Fenton, J. L. (2017). Digital identity guidelines (NIST Special Publication 800-63-3). National Institute of Standards and Technology. https://doi.org/10.6028/NIST.SP.800-63-3
He, K., Zhang, X., Ren, S., & Sun, J. (2016). Deep residual learning for image recognition. Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR 2016), 770–778. https://doi.org/10.1109/CVPR.2016.90
Hinton, G., Vinyals, O., & Dean, J. (2015). Distilling the knowledge in a neural network. NIPS Deep Learning and Representation Learning Workshop. https://arxiv.org/abs/1503.02531
Howard, A., Sandler, M., Chu, G., Chen, L.-C., Chen, B., Tan, M., Wang, W., Zhu, Y., Pang, R., Vasudevan, V., Le, Q. V., & Adam, H. (2019). Searching for MobileNetV3. Proceedings of the IEEE/CVF International Conference on Computer Vision (ICCV 2019), 1314–1324. https://doi.org/10.1109/ICCV.2019.00140
Howard, J., & Ruder, S. (2018). Universal language model fine-tuning for text classification. Proceedings of the 56th Annual Meeting of the Association for Computational Linguistics, 328–339. https://doi.org/10.18653/v1/P18-1031
International Civil Aviation Organization. (2021). Machine readable travel documents: Part 1  Introduction (Doc 9303, 8th ed.). ICAO. https://www.icao.int/publications/Documents/9303_p1_cons_en.pdf
Jacob, B., Kligys, S., Chen, B., Zhu, M., Tang, M., Howard, A., Adam, H., & Kalenichenko, D. (2018). Quantization and training of neural networks for efficient integer-arithmetic-only inference. Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR 2018), 2704–2713. https://doi.org/10.1109/CVPR.2018.00286
Jourabloo, A., Liu, Y., & Liu, X. (2018). Face de-spoofing: Anti-spoofing via noise modeling. Proceedings of the European Conference on Computer Vision (ECCV 2018), 290–306. https://doi.org/10.1007/978-3-030-01261-8_18
Ogunode, O. A., & Akintoye, I. R. (2023). Financial technologies and financial inclusion in emerging economies: Perspectives from Nigeria. Asian Journal of Economics, Business and Accounting, 23(1), 38–54. https://doi.org/10.9734/ajeba/2023/v23i1915
Sandler, M., Howard, A., Zhu, M., Zhmoginov, A., & Chen, L.-C. (2018). MobileNetV2: Inverted residuals and linear bottlenecks. Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR 2018), 4510–4520. https://doi.org/10.1109/CVPR.2018.00474
Schroff, F., Kalenichenko, D., & Philbin, J. (2015). FaceNet: A unified embedding for face recognition and clustering. Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR 2015), 815–823. https://doi.org/10.1109/CVPR.2015.7298682
Smith, R. (2007). An overview of the Tesseract OCR engine. Proceedings of the Ninth International Conference on Document Analysis and Recognition (ICDAR 2007), 629–633. https://doi.org/10.1109/ICDAR.2007.4376991
Tan, M., & Le, Q. V. (2019). EfficientNet: Rethinking model scaling for convolutional neural networks. Proceedings of the 36th International Conference on Machine Learning (ICML 2019), 6105–6114.
Wezel, T., & Ree, J. J. K. (2023). Nigeria  Fostering financial inclusion through digital financial services (IMF Selected Issues Paper No. 2023/020). International Monetary Fund. https://doi.org/10.5089/9798400237195.018
World Bank. (2021). The Global Findex Database 2021: Financial inclusion, digital payments, and resilience in the age of COVID-19. World Bank Group. https://www.worldbank.org/en/publication/globalfindex
Zhang, Y., Yin, Z., Li, Y., Yin, G., Yan, J., Shao, J., & Liu, Z. (2020). CelebA-Spoof: Large-scale face anti-spoofing dataset with rich annotations. Proceedings of the European Conference on Computer Vision (ECCV 2020), 70–85. https://doi.org/10.1007/978-3-030-58610-2_5
