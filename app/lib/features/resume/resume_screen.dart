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
          SnackBar(content: Text('Error selecting PDF: $e')),
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                      FilledButton.icon(
                        onPressed: () => _pickAndUploadResume(context, ref),
                        icon: const Icon(Icons.file_present),
                        label: Text(profile == null ? 'Select PDF File' : 'Upload New Resume'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(height: 8),
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
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                            if (profile.email != null)
                              Text(
                                profile.email!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (profile.location != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    profile.location!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Job Preference Controls Card
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
                            'Target Roles & Preferences',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            tooltip: 'Add Target Role',
                            onPressed: () => _showAddRoleDialog(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...state.targetRoles.map(
                            (role) => Chip(
                              label: Text(role),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () =>
                                  ref.read(resumeProvider.notifier).removeTargetRole(role),
                            ),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: const Text('Add Role'),
                            onPressed: () => _showAddRoleDialog(context, ref),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remote-Only Opportunities'),
                        subtitle: const Text('Prioritize 100% remote positions in match feed'),
                        value: state.isRemoteOnly,
                        onChanged: (val) =>
                            ref.read(resumeProvider.notifier).toggleRemoteOnly(val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Skills Section
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
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Skill'),
                            onPressed: () => _showAddSkillDialog(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.skills.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              skill,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Projects Section (Expandable Cards)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technical Projects (${profile.projects.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...profile.projects.map((proj) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          child: ExpansionTile(
                            title: Text(
                              proj.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: proj.techStack.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      proj.techStack.join(' • '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : null,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: proj.bulletPoints.map((bp) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              bp,
                                              style: const TextStyle(fontSize: 13, height: 1.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Education Section
              if (profile.education.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Education',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...profile.education.map((edu) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.school_outlined),
                            title: Text(edu.degree, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${edu.institution}${edu.graduationYear != null ? ' (${edu.graduationYear})' : ''}',
                            ),
                            trailing: edu.gpa != null ? Chip(label: Text('GPA ${edu.gpa}')) : null,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
