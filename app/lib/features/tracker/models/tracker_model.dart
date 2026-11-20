enum ApplicationStage {
  saved,
  applied,
  interview,
  offer,
  rejected,
}

extension ApplicationStageX on ApplicationStage {
  String get value {
    switch (this) {
      case ApplicationStage.saved:
        return 'saved';
      case ApplicationStage.applied:
        return 'applied';
      case ApplicationStage.interview:
        return 'interview';
      case ApplicationStage.offer:
        return 'offer';
      case ApplicationStage.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case ApplicationStage.saved:
        return 'Saved';
      case ApplicationStage.applied:
        return 'Applied';
      case ApplicationStage.interview:
        return 'Interview';
      case ApplicationStage.offer:
        return 'Offer';
      case ApplicationStage.rejected:
        return 'Archived';
    }
  }

  static ApplicationStage fromString(String val) {
    switch (val.toLowerCase()) {
      case 'applied':
        return ApplicationStage.applied;
      case 'interview':
        return ApplicationStage.interview;
      case 'offer':
        return ApplicationStage.offer;
      case 'rejected':
        return ApplicationStage.rejected;
      case 'saved':
      default:
        return ApplicationStage.saved;
    }
  }
}

class TrackedApplication {
  final String id;
  final String profileId;
  final String jobId;
  final ApplicationStage status;
  final String? company;
  final String? title;
  final String? location;
  final String? notes;
  final DateTime? updatedAt;

  const TrackedApplication({
    required this.id,
    required this.profileId,
    required this.jobId,
    required this.status,
    this.company,
    this.title,
    this.location,
    this.notes,
    this.updatedAt,
  });

  TrackedApplication copyWith({
    String? id,
    String? profileId,
    String? jobId,
    ApplicationStage? status,
    String? company,
    String? title,
    String? location,
    String? notes,
    DateTime? updatedAt,
  }) {
    return TrackedApplication(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      company: company ?? this.company,
      title: title ?? this.title,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TrackedApplication.fromJson(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>?;
    return TrackedApplication(
      id: json['id'] as String? ?? json['job_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      jobId: json['job_id'] as String? ?? '',
      status: ApplicationStageX.fromString(json['status'] as String? ?? 'saved'),
      company: job?['company'] as String? ?? json['company'] as String?,
      title: job?['title'] as String? ?? json['title'] as String?,
      location: job?['location'] as String? ?? json['location'] as String?,
      notes: json['notes'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
