import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feed_provider.dart';
import 'models/job_match.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981); // Emerald
    if (score >= 60) return const Color(0xFF6366F1); // Indigo
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
          const SnackBar(content: Text('Could not launch application URL.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedProvider);
    final theme = Theme.of(context);
    final jobs = state.filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('InternPulse Match Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Openings',
            onPressed: () => ref.read(feedProvider.notifier).fetchMatches(),
          ),
        ],
      ),
      body: Column(
        children: [
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
                    label: '80%+ Match',
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
                  : state.errorMessage != null && jobs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  state.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () =>
                                      ref.read(feedProvider.notifier).fetchMatches(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : jobs.isEmpty
                          ? const Center(
                              child: Text('No job openings match the selected filter.'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: jobs.length,
                              itemBuilder: (context, index) {
                                final job = jobs[index];
                                return _JobCard(
                                  job: job,
                                  scoreColor: _getScoreColor(job.matchScore),
                                  onTap: () => context.push('/feed/tailor', extra: job),
                                  onApply: () => _launchApplyUrl(context, job.applyUrl),
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
      label: Text(label),
      selected: selected,
      selectedColor: theme.colorScheme.primaryContainer,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? theme.colorScheme.onPrimaryContainer : null,
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Company & Match Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.company,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Color-coded Match Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 13, color: scoreColor),
                        const SizedBox(width: 4),
                        Text(
                          '${job.matchScore}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Location, Remote, and Posted Time Row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (job.location != null)
                    _MetaPill(
                      icon: Icons.place_outlined,
                      label: job.location!,
                    ),
                  if (job.isRemote)
                    const _MetaPill(
                      icon: Icons.public,
                      label: 'Remote',
                    ),
                  if (job.postedHoursAgo != null)
                    _MetaPill(
                      icon: Icons.access_time,
                      label: '${job.postedHoursAgo!.toStringAsFixed(1)}h ago',
                    ),
                  _MetaPill(
                    icon: Icons.source_outlined,
                    label: job.source,
                  ),
                ],
              ),

              // Ghost Job Warning Pill
              if (job.ghostJobFlag) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'Ghost Job Warning: Stale (>30d) or unrealistic requirements',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // 1-Sentence Match Reason
              if (job.matchReason.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job.matchReason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Matched vs. Missing Skills
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...job.matchedSkills.map((s) => _SkillChip(name: s, isMatched: true)),
                  ...job.missingSkills.map((s) => _SkillChip(name: s, isMatched: false)),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Tailor Resume'),
                  ),
                  FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Apply Now'),
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

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String name;
  final bool isMatched;

  const _SkillChip({required this.name, required this.isMatched});

  @override
  Widget build(BuildContext context) {
    final color = isMatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMatched ? Icons.check_circle_outline : Icons.help_outline,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
