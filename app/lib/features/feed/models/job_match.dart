class JobMatchItem {
  final String? id;
  final String externalId;
  final String title;
  final String company;
  final String? location;
  final bool isRemote;
  final String? applyUrl;
  final String source;
  final int matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final double? postedHoursAgo;
  final bool ghostJobFlag;
  final String matchReason;

  const JobMatchItem({
    this.id,
    required this.externalId,
    required this.title,
    required this.company,
    this.location,
    this.isRemote = false,
    this.applyUrl,
    required this.source,
    required this.matchScore,
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.postedHoursAgo,
    this.ghostJobFlag = false,
    required this.matchReason,
  });

  factory JobMatchItem.fromJson(Map<String, dynamic> json) {
    return JobMatchItem(
      id: json['id'] as String?,
      externalId: json['external_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Role',
      company: json['company'] as String? ?? 'Company',
      location: json['location'] as String?,
      isRemote: json['is_remote'] as bool? ?? false,
      applyUrl: json['apply_url'] as String?,
      source: json['source'] as String? ?? 'ATS',
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
      matchedSkills: (json['matched_skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      missingSkills: (json['missing_skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      postedHoursAgo: (json['posted_hours_ago'] as num?)?.toDouble(),
      ghostJobFlag: json['ghost_job_flag'] as bool? ?? false,
      matchReason: json['match_reason'] as String? ?? '',
    );
  }
}

class JobMatchResponse {
  final String profileId;
  final int totalMatches;
  final List<JobMatchItem> matches;

  const JobMatchResponse({
    required this.profileId,
    required this.totalMatches,
    this.matches = const [],
  });

  factory JobMatchResponse.fromJson(Map<String, dynamic> json) {
    return JobMatchResponse(
      profileId: json['profile_id'] as String? ?? '',
      totalMatches: json['total_matches'] as int? ?? 0,
      matches: (json['matches'] as List<dynamic>?)
              ?.map((e) => JobMatchItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
