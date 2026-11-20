import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  String _selectedRole = 'Software Engineer Intern';

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final List<String> _roleOptions = [
    'Software Engineer Intern',
    'Frontend Engineer Intern',
    'AI / ML Engineer Intern',
    'Data Science Intern',
    'Mobile (Flutter) Intern',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final success = await ref.read(authProvider.notifier).signUp(
          name: _signUpNameController.text,
          email: _signUpEmailController.text,
          password: _signUpPasswordController.text,
          targetRole: _selectedRole,
        );

    if (success && mounted) {
      context.go('/onboarding/resume');
    }
  }

  Future<void> _handleLogin() async {
    final success = await ref.read(authProvider.notifier).login(
          email: _loginEmailController.text,
          password: _loginPasswordController.text,
        );

    if (success && mounted) {
      context.go('/feed');
    }
  }

  void _handleDemoLogin() {
    ref.read(authProvider.notifier).loginAsDemo();
    if (mounted) {
      context.go('/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon & Branding
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'InternPulse',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI-Powered Job & Internship Matcher',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error Banner
                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: theme.colorScheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tabs: Sign In / Create Account
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor:
                          theme.colorScheme.onSurfaceVariant,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Create Account'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab Views
                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // --- Sign In Tab ---
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _loginEmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined),
                                hintText: 'you@university.edu',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _loginPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed:
                                  authState.isLoading ? null : _handleLogin,
                              icon: authState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(authState.isLoading
                                  ? 'Signing In...'
                                  : 'Sign In to InternPulse'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // --- Create Account Tab ---
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _signUpNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  hintText: 'e.g. Alex Chen',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _signUpEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Student / Personal Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  hintText: 'alex@stanford.edu',
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Target Career Track',
                                  prefixIcon: Icon(Icons.work_outline),
                                ),
                                items: _roleOptions.map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(role,
                                        style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedRole = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _signUpPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password (min 6 chars)',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed:
                                    authState.isLoading ? null : _handleSignUp,
                                icon: authState.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_rounded),
                                label: Text(authState.isLoading
                                    ? 'Creating Account...'
                                    : 'Create Account & Continue'),
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Divider with OR
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Demo Mode Button
                  OutlinedButton.icon(
                    onPressed: _handleDemoLogin,
                    icon: const Icon(Icons.flash_on_rounded,
                        color: Color(0xFFF59E0B)),
                    label: const Text('⚡ Instant Access (Demo Student Account)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: const Color(0xFFF59E0B).withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Try all features immediately with verified sample student credentials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
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
