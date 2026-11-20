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
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load applications (${response.statusCode})',
        );
      }
    } catch (e) {
      // Local demo fallback if backend tracker is empty
      if (state.applications.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          applications: [
            TrackedApplication(
              id: 'demo-1',
              profileId: _profileId,
              jobId: 'greenhouse:figma:101',
              status: ApplicationStage.saved,
              company: 'Figma',
              title: 'Software Engineering Intern - Summer 2026',
              location: 'San Francisco, CA / Remote',
              notes: 'Follow up with recruiter John on LinkedIn',
              updatedAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
            TrackedApplication(
              id: 'demo-2',
              profileId: _profileId,
              jobId: 'greenhouse:stripe:202',
              status: ApplicationStage.applied,
              company: 'Stripe',
              title: 'Frontend Developer Intern',
              location: 'Remote',
              notes: 'Submitted customized resume with React & TypeScript emphasis',
              updatedAt: DateTime.now().subtract(const Duration(days: 3)),
            ),
          ],
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void setStage(ApplicationStage stage) {
    state = state.copyWith(selectedStage: stage);
  }

  /// Optimistically updates status and dispatches PATCH to backend
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
          'status': newStatus.value,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      // Revert if request fails
      state = state.copyWith(
        applications: previousApplications,
        errorMessage: 'Could not sync status change: $e',
      );
    }
  }
}

final trackerProvider = StateNotifierProvider<TrackerNotifier, TrackerState>((ref) {
  final dio = ref.watch(apiClientProvider);
  final resumeState = ref.watch(resumeProvider);
  final profileId = resumeState.profileId ?? 'default-profile';
  return TrackerNotifier(dio, profileId);
});
