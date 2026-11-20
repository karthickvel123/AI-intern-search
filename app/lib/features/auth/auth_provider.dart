import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/user_profile.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserProfile? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserProfile? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String targetRole,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (name.trim().isEmpty || email.trim().isEmpty || password.length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please enter a valid name, email, and 6+ character password.',
      );
      return false;
    }

    final newUser = UserProfile(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim(),
      targetRole: targetRole.trim().isNotEmpty ? targetRole.trim() : 'Software Engineer Intern',
      hasUploadedResume: false,
      createdAt: DateTime.now(),
      isDemo: false,
    );

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: newUser,
    );
    return true;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Email and password cannot be empty.',
      );
      return false;
    }

    // Authenticate user
    final existingUser = UserProfile(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: email.split('@').first.replaceAll('.', ' ').toUpperCase(),
      email: email.trim(),
      targetRole: 'Software Engineer Intern',
      hasUploadedResume: true,
      createdAt: DateTime.now(),
      isDemo: false,
    );

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: existingUser,
    );
    return true;
  }

  void loginAsDemo() {
    final demoUser = UserProfile(
      id: 'usr_demo_intern',
      name: 'Alex Carter',
      email: 'alex.carter@stanford.edu',
      targetRole: 'Software Engineer Intern',
      hasUploadedResume: true,
      createdAt: DateTime.now(),
      isDemo: true,
    );

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: demoUser,
    );
  }

  void markResumeUploaded() {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(hasUploadedResume: true),
      );
    }
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
