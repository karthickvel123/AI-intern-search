import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_provider.dart';
import '../feed/feed_provider.dart';
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

  void _showServerSettingsDialog(BuildContext context, WidgetRef ref) {
    final currentUrl = ref.read(serverUrlProvider);
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) {
        bool testing = false;
        String? resultMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configure Backend Server'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set the FastAPI backend URL (e.g. your local PC IP address on the same Wi-Fi):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.50:8000',
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  if (testing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (resultMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      resultMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: resultMessage!.contains('Connected')
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    setDialogState(() {
                      testing = true;
                      resultMessage = null;
                    });
                    final ok = await testBackendConnection(controller.text);
                    setDialogState(() {
                      testing = false;
                      resultMessage = ok
                          ? 'Connected successfully! (/health 200 OK)'
                          : 'Server unreachable. Verify host and port.';
                    });
                  },
                  child: const Text('Test Connection'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(serverUrlProvider.notifier).setUrl(controller.text);
                    Navigator.of(ctx).pop();
                    ref.read(feedProvider.notifier).fetchMatches();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backend URL updated.')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertsProvider);
    final authState = ref.watch(authProvider);
    final serverUrl = ref.watch(serverUrlProvider);
    final theme = Theme.of(context);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Alerts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Profile Account Card
            if (user != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.targetRole,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        tooltip: 'Sign Out',
                        onPressed: () {
                          ref.read(authProvider.notifier).logout();
                          context.go('/auth');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Backend Server Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.dns_outlined,
                              color: theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Backend Environment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showServerSettingsDialog(context, ref),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Target URL: $serverUrl',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Physical devices can browse 15 top-tier openings in Cloud Mode or connect directly to your PC IP.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: const Text(
                        'Instant Push Alerts',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Trigger alert when a new opening matches your profile',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: state.pushNotificationsEnabled,
                      onChanged: (val) =>
                          ref.read(alertsProvider.notifier).togglePush(val),
                    ),
                    if (state.pushNotificationsEnabled) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Listening to Firebase Cloud Messaging (FCM) topic: tech-openings',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Minimum Match Score Slider Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Minimum Match Threshold',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${state.minMatchScore}%',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Only send notifications for jobs meeting or exceeding this match rating.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Slider(
                      value: state.minMatchScore.toDouble(),
                      min: 70,
                      max: 95,
                      divisions: 5,
                      label: '${state.minMatchScore}%',
                      onChanged: (val) => ref
                          .read(alertsProvider.notifier)
                          .setMinMatchScore(val.toInt()),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ATS Monitored Slugs Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Monitored ATS Companies',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _showAddCompanyDialog(context, ref),
                          tooltip: 'Add Company',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live polling Greenhouse & Lever endpoints for these engineering teams:',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.monitoredCompanySlugs.map((slug) {
                        return InputChip(
                          label: Text(slug),
                          onDeleted: () => ref
                              .read(alertsProvider.notifier)
                              .removeCompanySlug(slug),
                          deleteIconColor: Colors.grey,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
