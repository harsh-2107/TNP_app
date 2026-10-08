import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ErrorHelper {
  /// Logs the raw, detailed error to the console for developers,
  /// but returns a polished, user-friendly message for the UI.
  static String getPolishedMessage(Object error) {
    // 1. Log the raw error for developer debugging
    developer.log(
      'RAW ERROR: $error',
      name: 'ErrorHelper',
      error: error,
    );

    // 2. Return polished messages based on error type
    if (error is AuthApiException) {
      if (error.message.toLowerCase().contains('invalid login credentials')) {
        return 'Incorrect email or password.';
      }
      return 'Authentication failed. Please try again.';
    }
    
    if (error is PostgrestException) {
      return 'Failed to load data. Please check your connection.';
    }
    
    if (error is StorageException) {
      return 'File upload failed. Please try again.';
    }
    
    if (error is PlatformException) {
      if (error.code == 'network_error') {
        return 'No internet connection.';
      }
      return 'An unexpected platform error occurred.';
    }

    // Generic fallback for Exception or other types
    final stringError = error.toString().toLowerCase();
    if (stringError.contains('socket') || stringError.contains('clientexception')) {
      return 'Network error. Please check your connection.';
    }

    return 'Something went wrong. Please try again later.';
  }
}
