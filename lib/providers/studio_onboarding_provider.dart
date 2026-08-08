import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'secure_storage_service.dart';

const List<String> kOnboardingStepOrder = [
  'studio',
  'salon',
  'member_types',
  'payment_methods',
  'equipment',
  'users',
  'completed',
];

class StudioOnboardingState {
  final int? studioId;
  final bool onboardingCompleted;
  final String onboardingStep;
  final bool loading;
  final bool advancing;
  final String? error;

  const StudioOnboardingState({
    this.studioId,
    this.onboardingCompleted = false,
    this.onboardingStep = 'studio',
    this.loading = false,
    this.advancing = false,
    this.error,
  });

  StudioOnboardingState copyWith({
    int? studioId,
    bool? onboardingCompleted,
    String? onboardingStep,
    bool? loading,
    bool? advancing,
    String? error,
  }) {
    return StudioOnboardingState(
      studioId: studioId ?? this.studioId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      loading: loading ?? this.loading,
      advancing: advancing ?? this.advancing,
      error: error,
    );
  }
}

class StudioOnboardingAdvanceResult {
  final bool success;
  final bool requirementNotMet;
  final bool shouldRefetch;
  final String? requiredStep;
  final String? userMessage;

  const StudioOnboardingAdvanceResult({
    required this.success,
    this.requirementNotMet = false,
    this.shouldRefetch = false,
    this.requiredStep,
    this.userMessage,
  });
}

enum OnboardingGateDecision { incomplete, completed, unavailable, unauthorized }

class OnboardingGateResolution {
  final OnboardingGateDecision decision;
  final int? studioId;
  final String? onboardingStep;

  const OnboardingGateResolution({
    required this.decision,
    this.studioId,
    this.onboardingStep,
  });
}

final studioOnboardingProvider =
    StateNotifierProvider<StudioOnboardingProvider, StudioOnboardingState>(
      (ref) => StudioOnboardingProvider(),
    );

class StudioOnboardingProvider extends StateNotifier<StudioOnboardingState> {
  StudioOnboardingProvider() : super(const StudioOnboardingState());

  static String get _baseUrl =>
      '${ApiConfig.baseUrl}/settings/studio/onboarding';

  final SecureStorageService _storage = SecureStorageService();

  static const Set<String> _incompleteSteps = {
    'studio',
    'salon',
    'member_types',
    'payment_methods',
    'equipment',
    'users',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<OnboardingGateResolution> resolveOnboardingGate() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 401) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unauthorized,
        );
      }

      if (response.statusCode != 200) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unavailable,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unavailable,
        );
      }

      final rawStudioId = decoded['studioId'];
      int? studioId;
      if (rawStudioId is int) {
        studioId = rawStudioId;
      } else if (rawStudioId is num) {
        studioId = rawStudioId.toInt();
      } else {
        studioId = int.tryParse(rawStudioId?.toString() ?? '');
      }
      if (studioId == null || studioId <= 0) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unavailable,
        );
      }

      final rawCompleted = decoded['onboardingCompleted'];
      if (rawCompleted is! bool) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unavailable,
        );
      }

      final rawStep = decoded['onboardingStep'];
      final step = rawStep?.toString();
      if (step == null || !kOnboardingStepOrder.contains(step)) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unavailable,
        );
      }

      if (rawCompleted) {
        if (step != 'completed') {
          return const OnboardingGateResolution(
            decision: OnboardingGateDecision.unavailable,
          );
        }

        state = state.copyWith(
          studioId: studioId,
          onboardingCompleted: true,
          onboardingStep: step,
          error: null,
        );

        return OnboardingGateResolution(
          decision: OnboardingGateDecision.completed,
          studioId: studioId,
          onboardingStep: step,
        );
      }

      if (!_incompleteSteps.contains(step)) {
        return const OnboardingGateResolution(
          decision: OnboardingGateDecision.unavailable,
        );
      }

      state = state.copyWith(
        studioId: studioId,
        onboardingCompleted: false,
        onboardingStep: step,
        error: null,
      );

      return OnboardingGateResolution(
        decision: OnboardingGateDecision.incomplete,
        studioId: studioId,
        onboardingStep: step,
      );
    } on TimeoutException {
      return const OnboardingGateResolution(
        decision: OnboardingGateDecision.unavailable,
      );
    } catch (_) {
      return const OnboardingGateResolution(
        decision: OnboardingGateDecision.unavailable,
      );
    }
  }

  StudioOnboardingState? _strictStateFromMap(Map<String, dynamic> jsonMap) {
    final rawStep = jsonMap['onboardingStep'];
    final step = rawStep?.toString();
    if (step == null || !kOnboardingStepOrder.contains(step)) {
      return null;
    }

    final rawCompleted = jsonMap['onboardingCompleted'];
    if (rawCompleted is! bool) {
      return null;
    }
    final completed = rawCompleted;

    if (completed && step != 'completed') {
      return null;
    }
    if (!completed && !_incompleteSteps.contains(step)) {
      return null;
    }

    final rawStudioId = jsonMap['studioId'];

    int? studioId;
    if (rawStudioId is int) {
      studioId = rawStudioId;
    } else if (rawStudioId is num) {
      studioId = rawStudioId.toInt();
    } else {
      studioId = int.tryParse(rawStudioId?.toString() ?? '');
    }

    if (studioId == null || studioId <= 0) {
      return null;
    }

    return state.copyWith(
      studioId: studioId,
      onboardingCompleted: completed,
      onboardingStep: step,
      error: null,
    );
  }

  String _extractMessage(http.Response response) {
    if (response.body.isEmpty) {
      return 'Request failed';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
        final error = decoded['error']?.toString();
        if (error != null && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {}

    return response.body;
  }

  Future<void> fetchOnboardingStatus() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
      );

      if (response.statusCode != 200) {
        state = state.copyWith(
          loading: false,
          error: _extractMessage(response),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        state = state.copyWith(
          loading: false,
          error: 'Invalid onboarding response format.',
        );
        return;
      }

      final parsed = _strictStateFromMap(decoded);
      if (parsed == null) {
        state = state.copyWith(
          loading: false,
          error: 'Invalid onboarding response format.',
        );
        return;
      }

      state = parsed.copyWith(loading: false, advancing: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<StudioOnboardingAdvanceResult> advanceToStep(String nextStep) async {
    state = state.copyWith(advancing: true, error: null);

    try {
      final response = await http.patch(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
        body: jsonEncode({'onboardingStep': nextStep}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          state = state.copyWith(
            advancing: false,
            error: 'Invalid onboarding response format.',
          );
          return const StudioOnboardingAdvanceResult(
            success: false,
            userMessage: 'Invalid onboarding response format.',
          );
        }

        final parsed = _strictStateFromMap(decoded);
        if (parsed == null) {
          state = state.copyWith(
            advancing: false,
            error: 'Invalid onboarding response format.',
          );
          return const StudioOnboardingAdvanceResult(
            success: false,
            userMessage: 'Invalid onboarding response format.',
          );
        }

        state = parsed.copyWith(advancing: false);
        return const StudioOnboardingAdvanceResult(success: true);
      }

      String? requiredStep;
      String? rawError;
      String? missingRequirement;

      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            requiredStep = decoded['requiredStep']?.toString();
            rawError =
                decoded['error']?.toString() ?? decoded['message']?.toString();
            missingRequirement = decoded['missingRequirement']?.toString();
          }
        } catch (_) {}
      }

      final message = _extractMessage(response);
      final normalizedError = (rawError ?? message).toLowerCase();
      final requirementNotMet = normalizedError.contains('requirement not met');
      final invalidTransition =
          normalizedError.contains('invalid onboarding step') ||
          normalizedError.contains('cannot skip');
      final staleStep =
          requiredStep != null &&
          requiredStep.trim().isNotEmpty &&
          requiredStep.trim() != state.onboardingStep;

      final shouldRefetch = invalidTransition || staleStep;
      final safeMessage = requirementNotMet
          ? 'Onboarding requirement not met'
          : (message.trim().isNotEmpty
                ? message
                : 'Failed to advance onboarding step');

      state = state.copyWith(advancing: false, error: safeMessage);
      return StudioOnboardingAdvanceResult(
        success: false,
        requirementNotMet: requirementNotMet || missingRequirement != null,
        shouldRefetch: shouldRefetch,
        requiredStep: requiredStep,
        userMessage: safeMessage,
      );
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(advancing: false, error: message);
      return StudioOnboardingAdvanceResult(
        success: false,
        userMessage: message,
      );
    }
  }
}
