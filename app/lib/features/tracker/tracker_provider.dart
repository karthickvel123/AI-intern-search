import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../resume/resume_provider.dart';
import 'models/tracker_model.dart';

class TrackerState {
  final bool isLoading;
  final String? errorMessage;
  final List<TrackedApplication> applications;
  final ApplicationStage selectedStage;

  const TrackerState({
    this.isLoading = false,
    this.errorMessage,
    this.applications = const [],
    this.selectedStage = ApplicationStage.saved,
  });

  List<TrackedApplication> get applicationsInSelectedStage {
    return applications.where((a) => a.status == selectedStage).toList();
  }

  TrackerState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<TrackedApplication>? applications,
    ApplicationStage? selectedStage,
  }) {
    return TrackerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      applications: applications ?? this.applications,
      selectedStage: selectedStage ?? this.selectedStage,
    );
  }
}

class TrackerNotifier extends StateNotifier<TrackerState> {
  final Dio _dio;
  final String _profileId;

  TrackerNotifier(this._dio, this._profileId) : super(const TrackerState()) {
    fetchApplications();
  }

  Future<void> fetchApplications() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _dio.get(
        '/api/v1/tracker',
        queryParameters: {'profile_id': _profileId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = (response.data['applications'] as List<dynamic>?)
                ?.map((e) => TrackedApplication.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        state = state.copyWith(
          isLoading: false,
          applications: list,
        );
        return;
      }
    } catch (_) {
      // Local fallback
    }

    // Default applications if tracker is empty
    if (state.applications.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        applications: [
          TrackedApplication(
            id: 'demo-1',
            profileId: _profileId,
            jobId: 'stripe-swe-intern',
            status: ApplicationStage.saved,
            company: 'Stripe',
            title: 'Software Engineer Intern - Core Payments',
            location: 'San Francisco, CA / Remote',
            notes: 'Tailored resume for Stripe payments API stack',
            updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
          TrackedApplication(
            id: 'demo-2',
            profileId: _profileId,
            jobId: 'spotify-mobile-intern',
            status: ApplicationStage.applied,
            company: 'Spotify',
            title: 'Mobile Engineer Intern (Flutter / Android)',
            location: 'New York, NY / Remote',
            notes: 'Submitted customized resume with Flutter and Riverpod emphasis',
            updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          TrackedApplication(
            id: 'demo-3',
            profileId: _profileId,
            jobId: 'google-swe-intern',
            status: ApplicationStage.interview,
            company: 'Google',
            title: 'Software Engineering Intern - Summer 2025',
            location: 'Mountain View, CA',
            notes: 'Technical screen scheduled for next Tuesday',
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void setStage(ApplicationStage stage) {
    state = state.copyWith(selectedStage: stage);
  }

  void saveJob({
    required String jobId,
    required String company,
    required String title,
    String? location,
    String? notes,
  }) {
    if (state.applications.any((a) => a.jobId == jobId)) {
      return;
    }
    final newApp = TrackedApplication(
      id: 'app_${DateTime.now().millisecondsSinceEpoch}',
      profileId: _profileId,
      jobId: jobId,
      status: ApplicationStage.saved,
      company: company,
      title: title,
      location: location,
      notes: notes,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(applications: [newApp, ...state.applications]);
  }

  void removeApplication(String id) {
    state = state.copyWith(
      applications: state.applications.where((a) => a.id != id).toList(),
    );
  }

  /// Optimistically updates status and dispatches PATCH to backend if reachable
  Future<void> updateApplicationStatus({
    required String jobId,
    required ApplicationStage newStatus,
    String? notes,
  }) async {
    final previousApplications = state.applications;

    // 1. Optimistic update
    final updatedList = state.applications.map((app) {
      if (app.jobId == jobId) {
        return app.copyWith(
          status: newStatus,
          notes: notes ?? app.notes,
          updatedAt: DateTime.now(),
        );
      }
      return app;
    }).toList();

    state = state.copyWith(applications: updatedList);

    // 2. Dispatch PATCH to backend
    try {
      await _dio.patch(
        '/api/v1/tracker/$jobId',
        data: {
          'profile_id': _profileId,
          'status': newStatus.name,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (_) {
      // Keep optimistic update in local state
    }
  }
}

final trackerProvider = StateNotifierProvider<TrackerNotifier, TrackerState>((ref) {
  final dio = ref.watch(apiClientProvider);
  final resumeState = ref.watch(resumeProvider);
  final profileId = resumeState.profileId ?? 'default-profile';
  return TrackerNotifier(dio, profileId);
});
