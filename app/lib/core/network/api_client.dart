import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default fallback base URL determined by runtime environment
String getDefaultBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8000';
  }
  try {
    if (Platform.isAndroid) {
      // Default Android emulator loopback; physical devices will use cloud or custom IP
      return 'http://10.0.2.2:8000';
    }
  } catch (_) {}
  return 'http://localhost:8000';
}

/// Dynamic server URL notifier for runtime configuration
class ServerUrlNotifier extends StateNotifier<String> {
  ServerUrlNotifier() : super(getDefaultBaseUrl());

  void setUrl(String newUrl) {
    var formatted = newUrl.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    while (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    state = formatted;
  }

  void resetToDefault() {
    state = getDefaultBaseUrl();
  }
}

final serverUrlProvider = StateNotifierProvider<ServerUrlNotifier, String>((ref) {
  return ServerUrlNotifier();
});

/// Dio API Client configured with dynamic base URL and fast timeouts for mobile resilience
Dio createApiClient(String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      error: true,
      logPrint: (obj) => debugPrint('[Dio] $obj'),
    ),
  );

  return dio;
}

/// Riverpod provider for the dynamic Dio API client
final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(serverUrlProvider);
  return createApiClient(baseUrl);
});

/// Quick health check helper
Future<bool> testBackendConnection(String url) async {
  var target = url.trim();
  if (!target.startsWith('http://') && !target.startsWith('https://')) {
    target = 'http://$target';
  }
  while (target.endsWith('/')) {
    target = target.substring(0, target.length - 1);
  }

  try {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ));
    final res = await dio.get('$target/health');
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
