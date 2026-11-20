import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'resume_provider.dart';

class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  Future<void> _pickAndUploadResume(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        await ref.read(resumeProvider.notifier).uploadAndParseResume(file);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice selecting PDF: $e')),
        );
      }
    }
  }

  void _showAddRoleDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Target Role'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. AI Research Intern, Backend Engineer',
          ),
          onSubmitted: (val) {
            ref.read(resumeProvider.notifier).addTargetRole(val);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(resumeProvider.notifier).addTargetRole(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddSkillDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. PyTorch, Docker, Flutter',
          ),
          onSubmitted: (val) {
            ref.read(resumeProvider.notifier).addSkill(val);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(resumeProvider.notifier).addSkill(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resumeProvider);
    final theme = Theme.of(context);
    final profile = state.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Vault & Master Profile'),
        actions: [
          if (profile != null)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Re-upload PDF',
              onPressed: () => _pickAndUploadResume(context, ref),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload / Parse Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 30,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile == null ? 'Upload Your PDF Resume' : 'Resume Successfully Parsed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile == null
                          ? 'Extract skills, projects, and work history using PyMuPDF and Gemini Structured Output'
                          : 'Profile is synced and ready for AI match ranking',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      Text(
                        'Parsing with Gemini Structured JSON Output...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _pickAndUploadResume(context, ref),
                            icon: const Icon(Icons.file_present),
                            label: Text(profile == null ? 'Select PDF File' : 'Upload New Resume'),
                          ),
                          if (profile == null) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  ref.read(resumeProvider.notifier).loadSampleProfile(),
                              icon: const Icon(Icons.auto_awesome, color: Color(0xFF10B981)),
                              label: const Text('Try Sample Resume'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (state.successMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.successMessage!,
                        style: const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (profile != null) ...[
              const SizedBox(height: 20),

              // Candidate Header Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (profile.email != null)
                              Text(
                                profile.email!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (profile.location != null)
                              Text(
                                profile.location!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Target Roles Section
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
                            'Target Roles',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => _showAddRoleDialog(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.targetRoles.map((role) {
                          return Chip(
                            label: Text(role),
                            onDeleted: () =>
                                ref.read(resumeProvider.notifier).removeTargetRole(role),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Remote Preference Toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Remote Roles Only'),
                  subtitle: const Text('Prioritize remote-friendly and hybrid internships'),
                  value: state.isRemoteOnly,
                  onChanged: (val) =>
                      ref.read(resumeProvider.notifier).toggleRemoteOnly(val),
                ),
              ),

              const SizedBox(height: 16),

              // Skills Chips Section
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
                            'Extracted Skills (${profile.skills.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => _showAddSkillDialog(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.skills.map((skill) {
                          return Chip(
                            label: Text(skill, style: const TextStyle(fontSize: 12)),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Projects Section
              if (profile.projects.isNotEmpty) ...[
                Text(
                  'Projects (${profile.projects.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...profile.projects.map((proj) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proj.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (proj.techStack.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: proj.techStack
                                    .map((t) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            t,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                            if (proj.bulletPoints.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...proj.bulletPoints.map((bp) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Text(
                                            bp,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: theme.colorScheme.onSurfaceVariant,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    )),
              ],

              const SizedBox(height: 16),

              // Education Section
              if (profile.education.isNotEmpty) ...[
                Text(
                  'Education',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...profile.education.map((edu) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: Text(edu.institution, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${edu.degree}${edu.graduationYear != null ? ' • Class of ${edu.graduationYear}' : ''}${edu.gpa != null ? ' • GPA: ${edu.gpa}' : ''}',
                        ),
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
