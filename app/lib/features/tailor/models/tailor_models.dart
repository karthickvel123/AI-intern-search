class BulletDiff {
  final String originalBullet;
  final String tailoredBullet;
  final String reason;

  const BulletDiff({
    required this.originalBullet,
    required this.tailoredBullet,
    required this.reason,
  });

  factory BulletDiff.fromJson(Map<String, dynamic> json) {
    return BulletDiff(
      originalBullet: json['original_bullet'] as String? ?? '',
      tailoredBullet: json['tailored_bullet'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class TailorResumeResponse {
  final String jobId;
  final String profileId;
  final List<BulletDiff> bulletDiffs;
  final String referralDm;

  const TailorResumeResponse({
    required this.jobId,
    required this.profileId,
    this.bulletDiffs = const [],
    required this.referralDm,
  });

  factory TailorResumeResponse.fromJson(Map<String, dynamic> json) {
    return TailorResumeResponse(
      jobId: json['job_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      bulletDiffs: (json['bullet_diffs'] as List<dynamic>?)
              ?.map((e) => BulletDiff.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      referralDm: json['referral_dm'] as String? ?? '',
    );
  }
}
