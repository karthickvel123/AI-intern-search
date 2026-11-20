import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/tracker_model.dart';
import 'tracker_provider.dart';

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackerProvider);
    final theme = Theme.of(context);
    final displayedApps = state.applicationsInSelectedStage;

    int countForStage(ApplicationStage stage) {
      return state.applications.where((a) => a.status == stage).length;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Kanban Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Tracker',
            onPressed: () => ref.read(trackerProvider.notifier).fetchApplications(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tabs Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ApplicationStage>(
                segments: [
                  ButtonSegment(
                    value: ApplicationStage.saved,
                    label: Text('Saved (${countForStage(ApplicationStage.saved)})'),
                    icon: const Icon(Icons.bookmark_border, size: 16),
                  ),
                  ButtonSegment(
                    value: ApplicationStage.applied,
                    label: Text('Applied (${countForStage(ApplicationStage.applied)})'),
                    icon: const Icon(Icons.send_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ApplicationStage.interview,
                    label: Text('Interview (${countForStage(ApplicationStage.interview)})'),
                    icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ApplicationStage.offer,
                    label: Text('Offer (${countForStage(ApplicationStage.offer)})'),
                    icon: const Icon(Icons.celebration_outlined, size: 16),
                  ),
                ],
                selected: {state.selectedStage},
                onSelectionChanged: (newSelection) {
                  ref.read(trackerProvider.notifier).setStage(newSelection.first);
                },
              ),
            ),
          ),

          // Application Cards List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(trackerProvider.notifier).fetchApplications(),
              child: state.isLoading && state.applications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : displayedApps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No jobs in ${state.selectedStage.label} stage',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Save or apply to positions from the Match Feed',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayedApps.length,
                          itemBuilder: (context, index) {
                            final app = displayedApps[index];
                            return _TrackedJobCard(app: app);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackedJobCard extends ConsumerWidget {
  final TrackedApplication app;

  const _TrackedJobCard({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Company & Stage Selector Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.company ?? 'Company',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.title ?? 'Position',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stage Mover Dropdown Menu
                PopupMenuButton<ApplicationStage>(
                  tooltip: 'Move Pipeline Stage',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (newStage) {
                    ref.read(trackerProvider.notifier).updateApplicationStatus(
                          jobId: app.jobId,
                          newStatus: newStage,
                        );
                  },
                  itemBuilder: (context) => [
                    ...ApplicationStage.values.map(
                      (stage) => PopupMenuItem(
                        value: stage,
                        child: Row(
                          children: [
                            if (stage == app.status)
                              const Icon(Icons.check, size: 16, color: Colors.green)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text('Move to ${stage.label}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (app.location != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(app.location!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ],

            if (app.notes != null && app.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 15, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        app.notes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Stage Quick Action Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stage: ${app.status.label}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Row(
                  children: [
                    if (app.status == ApplicationStage.saved)
                      TextButton.icon(
                        icon: const Icon(Icons.send, size: 14),
                        label: const Text('Mark Applied'),
                        onPressed: () {
                          ref.read(trackerProvider.notifier).updateApplicationStatus(
                                jobId: app.jobId,
                                newStatus: ApplicationStage.applied,
                              );
                        },
                      ),
                    if (app.status == ApplicationStage.applied)
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: const Text('Mark Interview'),
                        onPressed: () {
                          ref.read(trackerProvider.notifier).updateApplicationStatus(
                                jobId: app.jobId,
                                newStatus: ApplicationStage.interview,
                              );
                        },
                      ),
                    if (app.status == ApplicationStage.interview)
                      TextButton.icon(
                        icon: const Icon(Icons.celebration, size: 14),
                        label: const Text('Mark Offer'),
                        onPressed: () {
                          ref.read(trackerProvider.notifier).updateApplicationStatus(
                                jobId: app.jobId,
                                newStatus: ApplicationStage.offer,
                              );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
