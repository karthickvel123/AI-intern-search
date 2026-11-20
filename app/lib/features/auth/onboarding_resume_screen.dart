import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../resume/resume_provider.dart';
import 'auth_provider.dart';

class OnboardingResumeScreen extends ConsumerStatefulWidget {
  const OnboardingResumeScreen({super.key});

  @override
  ConsumerState<OnboardingResumeScreen> createState() =>
      _OnboardingResumeScreenState();
}

class _OnboardingResumeScreenState
    extends ConsumerState<OnboardingResumeScreen> {
  bool _isProcessing = false;

  Future<void> _pickResume() async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        await ref.read(resumeProvider.notifier).uploadAndParseResume(file);
        ref.read(authProvider.notifier).markResumeUploaded();
        if (mounted) {
          context.go('/feed');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload notice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _loadSampleResume() {
    ref.read(resumeProvider.notifier).loadSampleProfile();
    ref.read(authProvider.notifier).markResumeUploaded();
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final userName = user?.name.isNotEmpty == true ? user!.name : 'Candidate';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Onboarding'),
        actions: [
          TextButton(
            onPressed: () => context.go('/feed'),
            child: const Text('Skip to Feed'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Step 2 of 2: Profile Setup',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Welcome, $userName!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your resume so our AI can extract your skills, education, and projects to calculate precise match scores against live tech openings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Option A: Upload PDF
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 44,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Upload Resume (PDF)',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Supports standard 1-2 page PDF resumes.',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _isProcessing ? null : _pickResume,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.folder_open),
                            label: Text(_isProcessing
                                ? 'Analyzing Resume...'
                                : 'Select PDF File'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Option B: Load Sample Profile
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFF10B981),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Use Sample Tech Profile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pre-fills Flutter, Python, FastAPI, Docker, and full-stack projects for instant evaluation.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _loadSampleResume,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Try Sample'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go('/feed'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Skip for now and browse jobs'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
