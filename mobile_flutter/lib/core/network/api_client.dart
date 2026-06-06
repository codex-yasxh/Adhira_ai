import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.baseUrl = 'http://10.46.16.252:8000',
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String baseUrl;

  Future<http.Response> getJson(
    String path, {
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    return _httpClient
        .get(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )
        .timeout(timeout);
  }

  Future<http.Response> postJson(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _httpClient
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  void close() {
    _httpClient.close();
  }
}