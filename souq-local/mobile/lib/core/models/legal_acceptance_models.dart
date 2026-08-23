class LegalPolicyRequirement {
  const LegalPolicyRequirement({
    required this.policyId,
    required this.policyVersion,
    required this.slug,
  });

  final String policyId;
  final String policyVersion;
  final String slug;

  factory LegalPolicyRequirement.fromJson(Map<String, dynamic> json) {
    return LegalPolicyRequirement(
      policyId: json['policy_id'] as String,
      policyVersion: json['policy_version'] as String,
      slug: json['slug'] as String,
    );
  }
}

class LegalAcceptanceStatus {
  const LegalAcceptanceStatus({
    required this.required,
    required this.pending,
    required this.accepted,
    required this.complete,
  });

  final List<LegalPolicyRequirement> required;
  final List<String> pending;
  final List<LegalPolicyRequirement> accepted;
  final bool complete;

  factory LegalAcceptanceStatus.fromJson(Map<String, dynamic> json) {
    return LegalAcceptanceStatus(
      required: (json['required'] as List<dynamic>? ?? const [])
          .map((item) =>
              LegalPolicyRequirement.fromJson(item as Map<String, dynamic>))
          .toList(),
      pending: (json['pending'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      accepted: (json['accepted'] as List<dynamic>? ?? const [])
          .map((item) =>
              LegalPolicyRequirement.fromJson(item as Map<String, dynamic>))
          .toList(),
      complete: json['complete'] as bool? ?? false,
    );
  }

  static const empty = LegalAcceptanceStatus(
    required: [],
    pending: [],
    accepted: [],
    complete: true,
  );
}
