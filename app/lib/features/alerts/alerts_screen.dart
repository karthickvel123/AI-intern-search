import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alerts_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  void _showAddCompanyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Target ATS Company Slug'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Greenhouse or Lever company slug (e.g. "openai", "stripe", "gusto", "canva").',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. openai',
              ),
              onSubmitted: (val) {
                ref.read(alertsProvider.notifier).addCompanySlug(val);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(alertsProvider.notifier).addCompanySlug(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Slug'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Alerts & Push Triggers'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Push Notification Toggle Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: const Text(
                        'Instant Push Notifications',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Receive high-priority alerts when new high-match internships are detected',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: state.pushNotificationsEnabled,
                      onChanged: (val) =>
                          ref.read(alertsProvider.notifier).togglePushNotifications(val),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Minimum Match Score Threshold Slider Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Minimum Match Threshold',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${state.minMatchScore.round()}% Match',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Only notify me if Gemini scores the job match at or above this percentage.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: state.minMatchScore,
                      min: 75.0,
                      max: 95.0,
                      divisions: 20,
                      label: '${state.minMatchScore.round()}%',
                      onChanged: (val) =>
                          ref.read(alertsProvider.notifier).setMinMatchScore(val),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('75% (More alerts)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('95% (Laser focused)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Target Company Slugs Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tracked Company ATS Slugs (${state.targetCompanySlugs.length})',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Slug'),
                          onPressed: () => _showAddCompanyDialog(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Live ATS feeds queried directly via Greenhouse and Lever connectors.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...state.targetCompanySlugs.map(
                          (slug) => Chip(
                            avatar: const Icon(Icons.business, size: 14),
                            label: Text(slug),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                ref.read(alertsProvider.notifier).removeCompanySlug(slug),
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Add Company'),
                          onPressed: () => _showAddCompanyDialog(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Firebase Cloud Messaging Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'FCM Push Service Integration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To enable real device push messaging:\n'
                    '• Android: Place google-services.json in android/app/\n'
                    '• iOS: Place GoogleService-Info.plist in ios/Runner/\n'
                    '• Notification handler is stubbed in lib/core/notifications/fcm_service.dart',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
