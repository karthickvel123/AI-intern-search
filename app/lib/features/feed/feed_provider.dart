import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../resume/models/master_profile.dart';
import '../resume/resume_provider.dart';
import 'curated_jobs.dart';
import 'models/job_match.dart';

enum FeedFilterType {
  all,
  highMatch,
  internships,
  remote,
}

class FeedState {
  final bool isLoading;
  final String? errorMessage;
  final String? bannerMessage;
  final bool isCuratedMode;
  final List<JobMatchItem> allJobs;
  final FeedFilterType selectedFilter;

  const FeedState({
    this.isLoading = false,
    this.errorMessage,
    this.bannerMessage,
    this.isCuratedMode = false,
    this.allJobs = const [],
    this.selectedFilter = FeedFilterType.all,
  });

  List<JobMatchItem> get filteredJobs {
    switch (selectedFilter) {
      case FeedFilterType.highMatch:
        return allJobs.where((j) => j.matchScore >= 85).toList();
      case FeedFilterType.internships:
        return allJobs
            .where((j) =>
                j.title.toLowerCase().contains('intern') ||
                j.title.toLowerCase().contains('co-op'))
            .toList();
      case FeedFilterType.remote:
        return allJobs.where((j) => j.isRemote).toList();
      case FeedFilterType.all:
      default:
        return allJobs;
    }
  }

  FeedState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? bannerMessage,
    bool? isCuratedMode,
    List<JobMatchItem>? allJobs,
    FeedFilterType? selectedFilter,
  }) {
    return FeedState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      bannerMessage: bannerMessage,
      isCuratedMode: isCuratedMode ?? this.isCuratedMode,
      allJobs: allJobs ?? this.allJobs,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final Dio _dio;
  final String _profileId;
  final MasterProfile? _profile;

  FeedNotifier(this._dio, this._profileId, this._profile)
      : super(const FeedState()) {
    fetchMatches();
  }

  Future<void> fetchMatches() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _dio.get(
        '/api/v1/jobs/matches',
        queryParameters: {
          'profile_id': _profileId.isNotEmpty ? _profileId : 'default-profile',
          'limit': 30,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final matchResponse = JobMatchResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        if (matchResponse.matches.isNotEmpty) {
          state = state.copyWith(
            isLoading: false,
            allJobs: matchResponse.matches,
            isCuratedMode: false,
            bannerMessage: null,
            errorMessage: null,
          );
          return;
        }
      }
    } catch (_) {
      // Graceful fallback to verified curated job listings
    }

    // Apply smart personalization against user profile if available
    final jobs = _personalizeJobs(kCuratedTechJobs, _profile);

    state = state.copyWith(
      isLoading: false,
      allJobs: jobs,
      isCuratedMode: true,
      bannerMessage: 'Showing 15 Curated Top-Tier Openings (Cloud / Offline Mode)',
      errorMessage: null,
    );
  }

  List<JobMatchItem> _personalizeJobs(
      List<JobMatchItem> jobs, MasterProfile? profile) {
    if (profile == null || profile.skills.isEmpty) {
      return jobs;
    }

    final userSkillsUpper =
        profile.skills.map((s) => s.toUpperCase()).toSet();

    return jobs.map((job) {
      final matched = <String>[];
      final missing = <String>[];

      for (final s in job.matchedSkills) {
        if (userSkillsUpper.contains(s.toUpperCase())) {
          matched.add(s);
        } else {
          missing.add(s);
        }
      }

      int score = job.matchScore;
      if (matched.isNotEmpty) {
        score = (75 + (matched.length * 5)).clamp(70, 98);
      }

      return JobMatchItem(
        id: job.id,
        title: job.title,
        company: job.company,
        location: job.location,
        isRemote: job.isRemote,
        description: job.description,
        applyUrl: job.applyUrl,
        postedHoursAgo: job.postedHoursAgo,
        ghostJobFlag: job.ghostJobFlag,
        matchScore: score,
        matchedSkills: matched.isNotEmpty ? matched : job.matchedSkills,
        missingSkills: missing.isNotEmpty ? missing : job.missingSkills,
        matchReason: job.matchReason,
      );
    }).toList();
  }

  void setFilter(FeedFilterType filter) {
    state = state.copyWith(selectedFilter: filter);
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final dio = ref.watch(apiClientProvider);
  final resumeState = ref.watch(resumeProvider);
  final profileId = resumeState.profileId ?? 'default-profile';
  final profile = resumeState.profile;
  return FeedNotifier(dio, profileId, profile);
});
