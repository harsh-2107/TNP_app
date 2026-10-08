import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';
import 'supabase_client_provider.dart';

class ApiClient {
  ApiClient(this._ref);
  final Ref _ref;

  Future<Map<String, String>> _getHeaders() async {
    final supabase = _ref.read(supabaseClientProvider);
    final session = supabase.auth.currentSession;

    if (session == null || session.accessToken.isEmpty) {
      throw StateError('No active Supabase session found for API request.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final response = await http.get(url, headers: headers);

    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final response = await http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final response = await http.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final response = await http.patch(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final response = await http.delete(url, headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> postMultipart(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    required String fileField,
  }) async {
    final headers = await _getHeaders();
    // For multipart, we should let the request set its own Content-Type with boundary
    headers.remove('Content-Type');

    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: filename),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  Future<http.Response> getRaw(String endpoint) async {
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    final url = Uri.parse('${AppConfig.backendApiUrl}$endpoint');

    final response = await http.get(url, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      String errorMessage = 'Server error: ${response.statusCode}';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson['detail'] != null) {
          errorMessage = errorJson['detail'].toString();
        } else if (errorJson['message'] != null) {
          errorMessage = errorJson['message'].toString();
        }
      } catch (_) {}
      if (response.statusCode == 401 &&
          (errorMessage.contains('Session invalidated') ||
              errorMessage.contains('role permissions were updated'))) {
        try {
          final supabase = _ref.read(supabaseClientProvider);
          await supabase.auth.signOut();
        } catch (_) {}
      }
      throw Exception(errorMessage);
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw FormatException(
          'Failed to parse response body: ${response.body}',
        );
      }
    } else {
      String errorMessage = 'Server error: ${response.statusCode}';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson['detail'] != null) {
          errorMessage = errorJson['detail'].toString();
        } else if (errorJson['message'] != null) {
          errorMessage = errorJson['message'].toString();
        }
      } catch (_) {}

      // Handle 401 Session Invalidation / Role update auto-logout
      if (response.statusCode == 401 &&
          (errorMessage.contains('Session invalidated') ||
              errorMessage.contains('role permissions were updated'))) {
        try {
          final supabase = _ref.read(supabaseClientProvider);
          supabase.auth.signOut();
        } catch (_) {}
      }

      throw Exception(errorMessage);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
