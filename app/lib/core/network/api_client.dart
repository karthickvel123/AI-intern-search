import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base URL determined by runtime environment
String getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8000';
  }
  try {
    if (Platform.isAndroid) {
      // Android emulator routes host localhost to 10.0.2.2
      return 'http://10.0.2.2:8000';
    }
  } catch (_) {
    // In case dart:io Platform is accessed where not supported
  }
  return 'http://localhost:8000';
}

/// Dio API Client configured with base URL, timeouts, and headers
Dio createApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: getBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
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

/// Riverpod provider for the singleton Dio API client
final apiClientProvider = Provider<Dio>((ref) {
  return createApiClient();
});
