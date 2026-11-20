import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../feed/models/job_match.dart';
import '../resume/resume_provider.dart';
import '../tracker/tracker_provider.dart';
import 'tailor_provider.dart';

class TailorScreen extends ConsumerWidget {
  final JobMatchItem job;

  const TailorScreen({super.key, required this.job});

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF10B981);
    if (score >= 80) return const Color(0xFF6366F1);
    return const Color(0xFF64748B);
  }

  Future<void> _launchApplyUrl(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No application URL provided for this position.')),
      );
      return;
    }
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tailorState = ref.watch(tailorProvider);
    final resumeState = ref.watch(resumeProvider);
    final profileId = resumeState.profileId ?? 'default-profile';
    final scoreColor = _getScoreColor(job.matchScore);

    final tailoredResponse = tailorState.tailoredResponse;

    return Scaffold(
      appBar: AppBar(
        title: Text(job.company),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save to Tracker',
            onPressed: () {
              ref.read(trackerProvider.notifier).saveJob(
                    jobId: job.id ?? job.externalId,
                    company: job.company,
                    title: job.title,
                    location: job.location,
                    notes: 'Tailored for ${job.company}',
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to Application Tracker!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Apply on Company Site',
            onPressed: () => _launchApplyUrl(context, job.applyUrl),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Job Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.company,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scoreColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${job.matchScore}% Match',
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (job.location != null)
                          Chip(
                            avatar: const Icon(Icons.location_on_outlined, size: 14),
                            label: Text(job.location!, style: const TextStyle(fontSize: 11)),
                          ),
                        if (job.isRemote)
                          Chip(
                            avatar: const Icon(Icons.wifi, size: 14),
                            label: const Text('Remote', style: TextStyle(fontSize: 11)),
                          ),
                        if (job.ghostJobFlag)
                          Chip(
                            avatar: const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                            label: const Text('Ghost Job Flagged', style: TextStyle(fontSize: 11, color: Colors.red)),
                            backgroundColor: Colors.red.withOpacity(0.1),
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Job Description:',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.description,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // AI Match Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'AI Match Analysis',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.matchReason.isNotEmpty
                          ? job.matchReason
                          : 'Evaluated based on your documented skills and project experiences.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Skill Comparison:',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...job.matchedSkills.map((s) => Chip(
                              avatar: const Icon(Icons.check, size: 14, color: Colors.green),
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.green.withOpacity(0.1),
                            )),
                        ...job.missingSkills.map((s) => Chip(
                              avatar: const Icon(Icons.priority_high, size: 14, color: Colors.orange),
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.orange.withOpacity(0.1),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tailor CTA Button
            FilledButton.icon(
              onPressed: tailorState.isLoading
                  ? null
                  : () {
                      ref.read(tailorProvider.notifier).tailorResume(
                            jobId: job.id ?? job.externalId,
                            profileId: profileId,
                            jobTitle: job.title,
                            companyName: job.company,
                          );
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: tailorState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(
                tailorState.isLoading
                    ? 'Tailoring with Zero-Hallucination Rule...'
                    : 'Tailor Resume for this Role',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            if (tailorState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tailorState.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],

            // Tailored Results
            if (tailoredResponse != null) ...[
              const SizedBox(height: 20),

              // Stacked Original vs. Tailored Bullet Diffs
              Text(
                'Tailored Resume Bullets',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Rephrased to emphasize relevant keywords using ONLY facts from your Master Profile.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              ...tailoredResponse.bulletDiffs.map((diff) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Original
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ORIGINAL BULLET',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(diff.originalBullet, style: const TextStyle(fontSize: 12, height: 1.3)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Tailored
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TAILORED BULLET (ZERO-HALLUCINATION)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: 'Copy Tailored Bullet',
                                    onPressed: () => _copyToClipboard(
                                      context,
                                      diff.tailoredBullet,
                                      'Tailored bullet',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                diff.tailoredBullet,
                                style: const TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        if (diff.reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${diff.reason}',
                            style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Referral DM Card
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mark_email_unread_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'LinkedIn Referral DM',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tailoredResponse.referralDm.split(' ').length} words',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        tailoredResponse.referralDm,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            context,
                            tailoredResponse.referralDm,
                            'LinkedIn referral message',
                          ),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Referral DM'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],

            // Final Apply Action
            FilledButton.tonalIcon(
              onPressed: () => _launchApplyUrl(context, job.applyUrl),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.launch, size: 18),
              label: Text('Apply on ${job.company} Website'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
