import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'models/tailor_models.dart';

class TailorState {
  final bool isLoading;
  final String? errorMessage;
  final TailorResumeResponse? tailoredResponse;

  const TailorState({
    this.isLoading = false,
    this.errorMessage,
    this.tailoredResponse,
  });

  TailorState copyWith({
    bool? isLoading,
    String? errorMessage,
    TailorResumeResponse? tailoredResponse,
  }) {
    return TailorState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      tailoredResponse: tailoredResponse ?? this.tailoredResponse,
    );
  }
}

class TailorNotifier extends StateNotifier<TailorState> {
  final Dio _dio;

  TailorNotifier(this._dio) : super(const TailorState());

  Future<void> tailorResume({
    required String jobId,
    required String profileId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _dio.post(
        '/api/v1/jobs/$jobId/tailor',
        data: {
          'profile_id': profileId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final parsed = TailorResumeResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
        state = state.copyWith(
          isLoading: false,
          tailoredResponse: parsed,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Server returned ${response.statusCode}: ${response.statusMessage}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Tailoring failed: $e',
      );
    }
  }

  void clear() {
    state = const TailorState();
  }
}

final tailorProvider = StateNotifierProvider<TailorNotifier, TailorState>((ref) {
  final dio = ref.watch(apiClientProvider);
  return TailorNotifier(dio);
});
