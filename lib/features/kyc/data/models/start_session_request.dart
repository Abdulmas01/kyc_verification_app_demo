import 'package:kyc_verification_app_demo/core/network/request_cancel_token.dart';

class StartSessionRequest {
  final String workflowKey;
  final String sourceType;
  final String? subjectReference;
  final String? subjectExternalId;
  final Map<String, dynamic>? subjectProfile;
  final Map<String, dynamic>? subjectContact;
  final Map<String, dynamic>? subjectMetadata;
  final RequestCancelToken? cancelToken;

  const StartSessionRequest({
    this.workflowKey = 'document_selfie_basic',
    this.sourceType = 'product_ui',
    this.subjectReference,
    this.subjectExternalId,
    this.subjectProfile,
    this.subjectContact,
    this.subjectMetadata,
    this.cancelToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'workflow_key': workflowKey,
      'source_type': sourceType,
      if (subjectReference != null && subjectReference!.isNotEmpty)
        'subject_reference': subjectReference,
      if (subjectExternalId != null && subjectExternalId!.isNotEmpty)
        'subject_external_id': subjectExternalId,
      if (subjectProfile != null && subjectProfile!.isNotEmpty)
        'subject_profile': subjectProfile,
      if (subjectContact != null && subjectContact!.isNotEmpty)
        'subject_contact': subjectContact,
      if (subjectMetadata != null && subjectMetadata!.isNotEmpty)
        'subject_metadata': subjectMetadata,
    };
  }
}
