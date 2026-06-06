import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/health_assistant_models.dart';

class HealthAssistantApiService {
  HealthAssistantApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<String> sendMessage({
    required String query,
    required String userId,
    List<Map<String, String>> history = const [],
    List<String> medicineNames = const [],
  }) async {
    if (query.trim().isEmpty) {
      return 'Something went wrong, try again.';
    }
    if (query.length > 4000) {
      return 'Something went wrong, try again.';
    }

    try {
      final response = await _apiClient.postJson(
        ApiEndpoints.healthAssistant,
        body: {
          'query': query.trim(),
          'user_id': userId,
          'history': history,
          if (medicineNames.isNotEmpty) 'medicine_names': medicineNames,
        },
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Something went wrong, try again.';
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return 'Something went wrong, try again.';
      }

      final aiResponseText = (decoded['response'] ?? '').toString();
      if (aiResponseText.trim().isEmpty) {
        return 'Something went wrong, try again.';
      }

      return aiResponseText;
    } catch (_) {
      return 'Something went wrong, try again.';
    }
  }

  /// Upload a medical document and get Adhira's analysis.
  /// Returns the AI response text, or a user-friendly error string.
  Future<String> analyzeDocument({
    required File file,
    required String mimeType,
    String question = 'Please explain this medical document.',
  }) async {
    try {
      final uri = Uri.parse('${_apiClient.baseUrl}${ApiEndpoints.analyzeDocument}');
      final req = http.MultipartRequest('POST', uri)
        ..fields['question'] = question
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: _mediaType(mimeType),
        ));

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 429) {
        return "I'm a little busy right now — my AI quota is full. Please try again in a moment.";
      }
      if (streamed.statusCode == 422) {
        final decoded = jsonDecode(body);
        return decoded['detail'] ?? 'Could not read this PDF. Try uploading a photo of the report.';
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final decoded = jsonDecode(body);
        return decoded['detail'] ?? 'Could not analyse the document. Please try again.';
      }

      final decoded = jsonDecode(body);
      return (decoded['response'] ?? '').toString();
    } on TimeoutException {
      return 'The analysis took too long. Please try again with a smaller file.';
    } catch (_) {
      return 'Could not analyse the document. Please check your connection and try again.';
    }
  }

  http.MediaType _mediaType(String mimeType) {
    final parts = mimeType.split('/');
    return http.MediaType(parts[0], parts.length > 1 ? parts[1] : '*');
  }

  Future<HealthAssistantResponse> askHealthAssistant(
    HealthAssistantRequest request,
  ) async {
    if (request.query.trim().isEmpty) {
      throw ApiException('Input text cannot be empty');
    }
    if (request.query.length > 4000) {
      throw ApiException('Input text is too long (max 4000 characters)');
    }

    try {
      final response = await _apiClient.postJson(
        ApiEndpoints.healthAssistant,
        body: request.toJson(),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode == 404) {
        throw ApiException(
          'Health assistant endpoint not found. Please check backend configuration.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        throw ApiException(
          'Too many requests. Please wait a moment before trying again.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode >= 500) {
        throw ApiException(
          'Server error. Please try again later.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'HTTP ${response.statusCode}: ${response.body.isEmpty ? 'Unknown error' : response.body}',
          statusCode: response.statusCode,
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Invalid response data structure');
      }

      // Preserve web-side behavior: frontend checks for `response` or `error`.
      if (!decoded.containsKey('response') && !decoded.containsKey('error')) {
        throw ApiException('No response content received from AI');
      }

      if (decoded['error'] != null) {
        throw ApiException('AI Error: ${decoded['error']}');
      }

      final aiResponseText = (decoded['response'] ?? '').toString();
      if (aiResponseText.trim().isEmpty) {
        throw ApiException('AI returned empty response');
      }

      return HealthAssistantResponse.fromJson(decoded);
    } on TimeoutException {
      throw ApiException('Request timed out. The AI took too long to respond. Please try again.');
    } on FormatException {
      throw ApiException('Invalid response format from server');
    }
  }
}
