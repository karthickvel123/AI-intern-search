import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/fcm_service.dart';

class AlertsState {
  final bool pushNotificationsEnabled;
  final double minMatchScore;
  final List<String> targetCompanySlugs;

  const AlertsState({
    this.pushNotificationsEnabled = true,
    this.minMatchScore = 80.0,
    this.targetCompanySlugs = const [
      'figma',
      'stripe',
      'cloudflare',
      'spotify',
      'netflix',
      'discord',
      'atlassian',
    ],
  });

  AlertsState copyWith({
    bool? pushNotificationsEnabled,
    double? minMatchScore,
    List<String>? targetCompanySlugs,
  }) {
    return AlertsState(
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      minMatchScore: minMatchScore ?? this.minMatchScore,
      targetCompanySlugs: targetCompanySlugs ?? this.targetCompanySlugs,
    );
  }
}

class AlertsNotifier extends StateNotifier<AlertsState> {
  AlertsNotifier() : super(const AlertsState());

  Future<void> togglePushNotifications(bool enabled) async {
    state = state.copyWith(pushNotificationsEnabled: enabled);
    if (enabled) {
      await FCMService.instance.requestPermission();
      await FCMService.instance.subscribeToJobAlertsTopic();
    } else {
      await FCMService.instance.unsubscribeFromJobAlertsTopic();
    }
  }

  void setMinMatchScore(double score) {
    state = state.copyWith(minMatchScore: score);
  }

  void addCompanySlug(String slug) {
    final cleaned = slug.trim().toLowerCase();
    if (cleaned.isNotEmpty && !state.targetCompanySlugs.contains(cleaned)) {
      state = state.copyWith(
        targetCompanySlugs: [...state.targetCompanySlugs, cleaned],
      );
    }
  }

  void removeCompanySlug(String slug) {
    state = state.copyWith(
      targetCompanySlugs: state.targetCompanySlugs.where((s) => s != slug).toList(),
    );
  }
}

final alertsProvider = StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  return AlertsNotifier();
});
