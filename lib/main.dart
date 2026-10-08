import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress RenderFlex overflow errors and replace yellow/black hazard stripes
  FlutterError.onError = (FlutterErrorDetails details) {
    final isOverflow = details.exceptionAsString().contains('RenderFlex overflowed');
    if (isOverflow) {
      debugPrint('[Suppressed Layout Overflow] ${details.exception}');
    } else {
      FlutterError.presentError(details);
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    final isOverflow = details.exceptionAsString().contains('RenderFlex overflowed');
    if (isOverflow) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Unable to render view: ${details.exception.toString().split('\n').first}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ),
    );
  };

  String supabaseUrl = AppConfig.supabaseUrl;
  String supabaseAnonKey = AppConfig.supabaseAnonKey;

  try {
    // Attempt to dynamically fetch config from backend with a 3-second timeout
    final response = await http
        .get(Uri.parse('${AppConfig.backendApiUrl}/api/config'))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      supabaseUrl = data['supabaseUrl'];
      supabaseAnonKey = data['supabaseAnonKey'];
      print('Successfully fetched Supabase config from backend.');
    } else {
      print('Failed to fetch config from backend: ${response.statusCode}');
    }
  } catch (e) {
    print('Failed to reach backend for config: $e');
  }

  // Fallback to empty strings will cause an assertion error if backend is unreachable
  // and no dart defines were provided.
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    debug: AppConfig.isDevelopment,
  );

  runApp(const ProviderScope(child: App()));
}
