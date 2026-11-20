import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_provider.dart';
import 'feed_provider.dart';
import 'models/job_match.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF10B981); // Emerald
    if (score >= 80) return const Color(0xFF6366F1); // Indigo
    return const Color(0xFF64748B); // Slate
  }

  Future<void> _launchApplyUrl(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No application URL provided for this listing.')),
      );
      return;
    }
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external career link.')),
        );
      }
    }
  }

  void _showServerSettingsModal(BuildContext context, WidgetRef ref) {
    final currentUrl = ref.read(serverUrlProvider);
    final controller = TextEditingController(text: currentUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool testing = false;
        String? testResult;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Backend Server Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To connect your phone to your PC backend, enter your local Wi-Fi IP address (e.g. http://192.168.1.50:8000).',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'FastAPI Backend URL',
                      prefixIcon: const Icon(Icons.dns_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: 'Test Connection',
                        onPressed: () async {
                          setModalState(() {
                            testing = true;
                            testResult = null;
                          });
                          final ok = await testBackendConnection(controller.text);
                          setModalState(() {
                            testing = false;
                            testResult = ok
                                ? 'Connected successfully! (/health 200 OK)'
                                : 'Could not reach server. Verify IP and port.';
                          });
                        },
                      ),
                    ),
                  ),
                  if (testing) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                  if (testResult != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: testResult!.contains('success')
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref
                                .read(serverUrlProvider.notifier)
                                .resetToDefault();
                            Navigator.of(ctx).pop();
                            ref.read(feedProvider.notifier).fetchMatches();
                          },
                          child: const Text('Reset Default'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            ref
                                .read(serverUrlProvider.notifier)
                                .setUrl(controller.text);
                            Navigator.of(ctx).pop();
                            ref.read(feedProvider.notifier).fetchMatches();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backend URL saved.'),
                              ),
                            );
                          },
                          child: const Text('Save & Reconnect'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final jobs = state.filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'InternPulse Match Feed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (authState.user != null)
              Text(
                'Targeting: ${authState.user!.targetRole}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Server Settings',
            onPressed: () => _showServerSettingsModal(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Openings',
            onPressed: () => ref.read(feedProvider.notifier).fetchMatches(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Indicator
          if (state.bannerMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF6366F1).withOpacity(0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded,
                      size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.bannerMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showServerSettingsModal(context, ref),
                    child: const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                    label: 'All (${state.allJobs.length})',
                    selected: state.selectedFilter == FeedFilterType.all,
                    onSelected: () =>
                        ref.read(feedProvider.notifier).setFilter(FeedFilterType.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: '⭐ 85%+ Match',
                    selected: state.selectedFilter == FeedFilterType.highMatch,
                    onSelected: () =>
                        ref.read(feedProvider.notifier).setFilter(FeedFilterType.highMatch),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: '⚡ Internships',
                    selected: state.selectedFilter == FeedFilterType.internships,
                    onSelected: () =>
                        ref.read(feedProvider.notifier).setFilter(FeedFilterType.internships),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: '🌐 Remote',
                    selected: state.selectedFilter == FeedFilterType.remote,
                    onSelected: () =>
                        ref.read(feedProvider.notifier).setFilter(FeedFilterType.remote),
                  ),
                ],
              ),
            ),
          ),

          // Main Feed List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(feedProvider.notifier).fetchMatches(),
              child: state.isLoading && jobs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Ranking live tech openings with Gemini...'),
                        ],
                      ),
                    )
                  : jobs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.work_off_outlined,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text(
                                  'No openings match the selected filter.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => ref
                                      .read(feedProvider.notifier)
                                      .setFilter(FeedFilterType.all),
                                  child: const Text('Show All Jobs'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) {
                            final job = jobs[index];
                            return _JobCard(
                              job: job,
                              scoreColor: _getScoreColor(job.matchScore),
                              onTap: () =>
                                  context.push('/feed/tailor', extra: job),
                              onApply: () =>
                                  _launchApplyUrl(context, job.applyUrl),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected
              ? Colors.white
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobMatchItem job;
  final Color scoreColor;
  final VoidCallback onTap;
  final VoidCallback onApply;

  const _JobCard({
    required this.job,
    required this.scoreColor,
    required this.onTap,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Company, Posted time, Match Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        job.company.isNotEmpty ? job.company[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${job.company} • ${job.location}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scoreColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      '${job.matchScore}%',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Badges: Posted Time & Ghost Job Flag
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Posted ${job.postedHoursAgo}h ago',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (job.isRemote)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '🌐 Remote',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF818CF8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (job.ghostJobFlag)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: const Text(
                        '⚠️ Ghost Job Flagged',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Match Reason
              Text(
                job.matchReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              // Skills preview
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...job.matchedSkills.take(3).map(
                        (skill) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '✓ $skill',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  if (job.missingSkills.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+ ${job.missingSkills.length} missing',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Tailor Resume'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Apply'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
