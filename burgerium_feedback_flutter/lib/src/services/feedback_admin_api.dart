import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/feedback_models.dart';

abstract class FeedbackAdminApi {
  Future<AdminFeedbackDashboard> fetchDashboard({
    required String username,
    required String password,
  });
}

class HttpFeedbackAdminApi implements FeedbackAdminApi {
  HttpFeedbackAdminApi({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  Uri get _dashboardUri => baseUri.resolve('api/feedback/admin');

  @override
  Future<AdminFeedbackDashboard> fetchDashboard({
    required String username,
    required String password,
  }) async {
    final trimmedUsername = username.trim();
    final rawPassword = password;

    if (trimmedUsername.isEmpty || rawPassword.trim().isEmpty) {
      throw const AdminFeedbackApiException(
        'Enter both admin username and password.',
      );
    }

    try {
      final response = await _client
          .get(
            _dashboardUri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization':
                  'Basic ${base64Encode(utf8.encode('$trimmedUsername:$rawPassword'))}',
            },
          )
          .timeout(const Duration(seconds: 12));

      final payload = _decodeJson(response.body);

      if (response.statusCode == 401) {
        throw const AdminFeedbackApiException(
          'Invalid admin username or password.',
        );
      }

      if (response.statusCode == 503) {
        throw AdminFeedbackApiException(
          _errorMessageFromPayload(payload) ??
              'Admin dashboard is not configured on the server.',
        );
      }

      if (response.statusCode != 200) {
        throw AdminFeedbackApiException(
          _errorMessageFromPayload(payload) ??
              'Admin dashboard failed (${response.statusCode}).',
        );
      }

      if (payload is! Map<String, dynamic>) {
        throw const AdminFeedbackApiException(
          'Admin dashboard returned an invalid response.',
        );
      }

      return AdminFeedbackDashboard.fromJson(payload);
    } on TimeoutException {
      throw const AdminFeedbackApiException(
        'Admin dashboard took too long to respond.',
      );
    } on AdminFeedbackApiException {
      rethrow;
    } catch (_) {
      throw const AdminFeedbackApiException(
        'Unable to reach the admin dashboard right now.',
      );
    }
  }

  Map<String, dynamic>? _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  String? _errorMessageFromPayload(Map<String, dynamic>? payload) {
    final value = payload?['error'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}

class AdminFeedbackApiException implements Exception {
  const AdminFeedbackApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
