class UserProfile {
  final String id;
  final String name;
  final String email;
  final String targetRole;
  final bool hasUploadedResume;
  final DateTime createdAt;
  final bool isDemo;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.targetRole,
    this.hasUploadedResume = false,
    required this.createdAt,
    this.isDemo = false,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? targetRole,
    bool? hasUploadedResume,
    DateTime? createdAt,
    bool? isDemo,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      targetRole: targetRole ?? this.targetRole,
      hasUploadedResume: hasUploadedResume ?? this.hasUploadedResume,
      createdAt: createdAt ?? this.createdAt,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'target_role': targetRole,
    'has_uploaded_resume': hasUploadedResume,
    'created_at': createdAt.toIso8601String(),
    'is_demo': isDemo,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String? ?? 'user-1',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    targetRole: json['target_role'] as String? ?? 'Software Engineer Intern',
    hasUploadedResume: json['has_uploaded_resume'] as bool? ?? false,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
    isDemo: json['is_demo'] as bool? ?? false,
  );
}
