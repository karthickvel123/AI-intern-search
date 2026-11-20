class JobMatchItem {
  final String? id;
  final String externalId;
  final String title;
  final String company;
  final String? location;
  final bool isRemote;
  final String description;
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
    this.externalId = '',
    required this.title,
    required this.company,
    this.location,
    this.isRemote = false,
    this.description = '',
    this.applyUrl,
    this.source = 'ATS',
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
      description: json['description'] as String? ?? '',
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
      postedHoursAgo: (json['posted_hours_ago'] as num?)?.toDouble() ?? 1.0,
      ghostJobFlag: json['ghost_job_flag'] as bool? ?? false,
      matchReason: json['match_reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'external_id': externalId,
        'title': title,
        'company': company,
        if (location != null) 'location': location,
        'is_remote': isRemote,
        'description': description,
        if (applyUrl != null) 'apply_url': applyUrl,
        'source': source,
        'match_score': matchScore,
        'matched_skills': matchedSkills,
        'missing_skills': missingSkills,
        if (postedHoursAgo != null) 'posted_hours_ago': postedHoursAgo,
        'ghost_job_flag': ghostJobFlag,
        'match_reason': matchReason,
      };
}

class JobMatchResponse {
  final String profileId;
  final int totalMatches;
  final List<JobMatchItem> matches;

  const JobMatchResponse({
    required this.profileId,
    required this.totalMatches,
    required this.matches,
  });

  factory JobMatchResponse.fromJson(Map<String, dynamic> json) {
    return JobMatchResponse(
      profileId: json['profile_id'] as String? ?? '',
      totalMatches: (json['total_matches'] as num?)?.toInt() ?? 0,
      matches: (json['matches'] as List<dynamic>?)
              ?.map((e) => JobMatchItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'total_matches': totalMatches,
        'matches': matches.map((m) => m.toJson()).toList(),
      };
}
