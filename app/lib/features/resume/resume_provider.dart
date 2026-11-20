import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'models/master_profile.dart';

class ResumeState {
  final bool isLoading;
  final String? errorMessage;
  final MasterProfile? profile;
  final String? profileId;
  final bool isRemoteOnly;
  final List<String> targetRoles;
  final List<String> preferredLocations;

  const ResumeState({
    this.isLoading = false,
    this.errorMessage,
    this.profile,
    this.profileId,
    this.isRemoteOnly = true,
    this.targetRoles = const [],
    this.preferredLocations = const [],
  });

  ResumeState copyWith({
    bool? isLoading,
    String? errorMessage,
    MasterProfile? profile,
    String? profileId,
    bool? isRemoteOnly,
    List<String>? targetRoles,
    List<String>? preferredLocations,
  }) {
    return ResumeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      profile: profile ?? this.profile,
      profileId: profileId ?? this.profileId,
      isRemoteOnly: isRemoteOnly ?? this.isRemoteOnly,
      targetRoles: targetRoles ?? this.targetRoles,
      preferredLocations: preferredLocations ?? this.preferredLocations,
    );
  }
}

class ResumeNotifier extends StateNotifier<ResumeState> {
  final Dio _dio;

  ResumeNotifier(this._dio) : super(const ResumeState());

  Future<void> uploadAndParseResume(PlatformFile file) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      MultipartFile multipartFile;

      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('File bytes are missing in web environment.');
        }
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        );
      } else {
        if (file.path != null) {
          multipartFile = await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
          );
        } else if (file.bytes != null) {
          multipartFile = MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
          );
        } else {
          throw Exception('Could not locate file path or bytes on device.');
        }
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await _dio.post(
        '/api/v1/resume/parse',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final parseResponse = ResumeParseResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        final masterProfile = parseResponse.masterProfile;
        state = state.copyWith(
          isLoading: false,
          profile: masterProfile,
          profileId: parseResponse.profileId ?? 'local-profile',
          targetRoles: List<String>.from(masterProfile.targetRoles),
          preferredLocations: masterProfile.location != null
              ? [masterProfile.location!]
              : ['Remote'],
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Server returned ${response.statusCode}: ${response.statusMessage}',
        );
      }
    } catch (e) {
      debugPrint('Resume parsing failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to upload/parse resume: $e',
      );
    }
  }

  void updateTargetRoles(List<String> roles) {
    state = state.copyWith(targetRoles: roles);
  }

  void addTargetRole(String role) {
    if (role.trim().isNotEmpty && !state.targetRoles.contains(role.trim())) {
      state = state.copyWith(targetRoles: [...state.targetRoles, role.trim()]);
    }
  }

  void removeTargetRole(String role) {
    state = state.copyWith(
      targetRoles: state.targetRoles.where((r) => r != role).toList(),
    );
  }

  void toggleRemoteOnly(bool value) {
    state = state.copyWith(isRemoteOnly: value);
  }

  void addSkill(String skill) {
    if (state.profile != null && skill.trim().isNotEmpty) {
      final updatedSkills = [...state.profile!.skills, skill.trim()];
      state = state.copyWith(
        profile: state.profile!.copyWith(skills: updatedSkills),
      );
    }
  }
}

final resumeProvider = StateNotifierProvider<ResumeNotifier, ResumeState>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ResumeNotifier(dio);
});
