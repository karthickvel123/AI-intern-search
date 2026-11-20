class EducationItem {
  final String institution;
  final String degree;
  final String? graduationYear;
  final String? gpa;

  const EducationItem({
    required this.institution,
    required this.degree,
    this.graduationYear,
    this.gpa,
  });

  factory EducationItem.fromJson(Map<String, dynamic> json) {
    return EducationItem(
      institution: json['institution'] as String? ?? '',
      degree: json['degree'] as String? ?? '',
      graduationYear: json['graduation_year'] as String?,
      gpa: json['gpa'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'institution': institution,
    'degree': degree,
    if (graduationYear != null) 'graduation_year': graduationYear,
    if (gpa != null) 'gpa': gpa,
  };
}

class ProjectItem {
  final String title;
  final List<String> techStack;
  final List<String> bulletPoints;
  final String? link;

  const ProjectItem({
    required this.title,
    this.techStack = const [],
    this.bulletPoints = const [],
    this.link,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      title: json['title'] as String? ?? 'Untitled Project',
      techStack: (json['tech_stack'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      bulletPoints: (json['bullet_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      link: json['link'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'tech_stack': techStack,
    'bullet_points': bulletPoints,
    if (link != null) 'link': link,
  };
}

class ExperienceItem {
  final String company;
  final String role;
  final String? location;
  final String? startDate;
  final String? endDate;
  final List<String> bulletPoints;

  const ExperienceItem({
    required this.company,
    required this.role,
    this.location,
    this.startDate,
    this.endDate,
    this.bulletPoints = const [],
  });

  factory ExperienceItem.fromJson(Map<String, dynamic> json) {
    return ExperienceItem(
      company: json['company'] as String? ?? '',
      role: json['role'] as String? ?? '',
      location: json['location'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      bulletPoints: (json['bullet_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'company': company,
    'role': role,
    if (location != null) 'location': location,
    if (startDate != null) 'start_date': startDate,
    if (endDate != null) 'end_date': endDate,
    'bullet_points': bulletPoints,
  };
}

class MasterProfile {
  final String name;
  final String? email;
  final String? phone;
  final String? location;
  final List<EducationItem> education;
  final List<String> skills;
  final List<ProjectItem> projects;
  final List<ExperienceItem> experience;
  final List<String> targetRoles;

  const MasterProfile({
    required this.name,
    this.email,
    this.phone,
    this.location,
    this.education = const [],
    this.skills = const [],
    this.projects = const [],
    this.experience = const [],
    this.targetRoles = const [],
  });

  MasterProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    List<EducationItem>? education,
    List<String>? skills,
    List<ProjectItem>? projects,
    List<ExperienceItem>? experience,
    List<String>? targetRoles,
  }) {
    return MasterProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      education: education ?? this.education,
      skills: skills ?? this.skills,
      projects: projects ?? this.projects,
      experience: experience ?? this.experience,
      targetRoles: targetRoles ?? this.targetRoles,
    );
  }

  factory MasterProfile.fromJson(Map<String, dynamic> json) {
    return MasterProfile(
      name: json['name'] as String? ?? 'Candidate',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      location: json['location'] as String?,
      education: (json['education'] as List<dynamic>?)
              ?.map((e) => EducationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      projects: (json['projects'] as List<dynamic>?)
              ?.map((e) => ProjectItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      experience: (json['experience'] as List<dynamic>?)
              ?.map((e) => ExperienceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      targetRoles: (json['target_roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (location != null) 'location': location,
    'education': education.map((e) => e.toJson()).toList(),
    'skills': skills,
    'projects': projects.map((e) => e.toJson()).toList(),
    'experience': experience.map((e) => e.toJson()).toList(),
    'target_roles': targetRoles,
  };
}

class ResumeParseResponse {
  final String? profileId;
  final MasterProfile masterProfile;
  final int embeddingDimension;
  final bool savedToDb;
  final String message;

  const ResumeParseResponse({
    this.profileId,
    required this.masterProfile,
    this.embeddingDimension = 768,
    this.savedToDb = false,
    this.message = '',
  });

  factory ResumeParseResponse.fromJson(Map<String, dynamic> json) {
    return ResumeParseResponse(
      profileId: json['profile_id'] as String?,
      masterProfile: MasterProfile.fromJson(
        json['master_profile'] as Map<String, dynamic>? ?? {},
      ),
      embeddingDimension: json['embedding_dimension'] as int? ?? 768,
      savedToDb: json['saved_to_db'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}
