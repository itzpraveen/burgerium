import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/feedback_models.dart';

abstract class FeedbackApi {
  Future<FeedbackAvailability> fetchAvailability();

  Future<FeedbackSubmissionResult> submitFeedback(FeedbackDraft draft);
}

class HttpFeedbackApi implements FeedbackApi {
  HttpFeedbackApi({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  Uri get _feedbackApiUri => baseUri.resolve('api/feedback');

  @override
  Future<FeedbackAvailability> fetchAvailability() async {
    try {
      final response = await _client
          .get(
            _feedbackApiUri,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final payload = _decodeJsonMap(response.body);
      final availability = _availabilityFromPayload(payload);
      if (availability != null) {
        return availability;
      }

      if (response.statusCode == 503) {
        return FeedbackAvailability(
          isReachable: true,
          isConfigured: false,
          label: 'Temporarily unavailable',
          message:
              _errorMessageFromPayload(payload) ??
              'Feedback storage is unavailable on the server right now.',
        );
      }

      if (response.statusCode != 200) {
        throw FeedbackApiException(
          'Feedback service failed (${response.statusCode}).',
          type: FeedbackApiFailureType.server,
        );
      }

      return const FeedbackAvailability(
        isReachable: true,
        isConfigured: true,
        label: 'Ready',
      );
    } on TimeoutException {
      return const FeedbackAvailability.offline(
        message: 'The feedback server took too long to respond.',
      );
    } on FeedbackApiException catch (error) {
      return FeedbackAvailability.offline(message: error.message);
    } catch (_) {
      return const FeedbackAvailability.offline(
        message: 'Unable to reach the feedback service right now.',
      );
    }
  }

  @override
  Future<FeedbackSubmissionResult> submitFeedback(FeedbackDraft draft) async {
    try {
      final response = await _client
          .post(
            _feedbackApiUri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(draft.toApiPayload()),
          )
          .timeout(const Duration(seconds: 12));

      final payload = _decodeJsonMap(response.body);

      if (response.statusCode == 400) {
        throw FeedbackApiException(
          _errorMessageFromPayload(payload) ??
              'Check the required fields and try again.',
          type: FeedbackApiFailureType.invalidRequest,
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const FeedbackApiException(
          'The feedback service rejected this submission.',
          type: FeedbackApiFailureType.unauthorized,
        );
      }

      if (response.statusCode == 503) {
        throw FeedbackApiException(
          _errorMessageFromPayload(payload) ??
              'Feedback storage is unavailable right now.',
          type: FeedbackApiFailureType.unavailable,
        );
      }

      if (response.statusCode >= 500) {
        throw FeedbackApiException(
          _errorMessageFromPayload(payload) ??
              'Feedback submission failed on the server.',
          type: FeedbackApiFailureType.server,
        );
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw FeedbackApiException(
          _errorMessageFromPayload(payload) ??
              'Feedback submission failed (${response.statusCode}).',
          type: FeedbackApiFailureType.unknown,
        );
      }

      final submission = _submissionFromPayload(payload);
      if (submission == null) {
        throw const FeedbackApiException(
          'Feedback service returned an invalid response.',
          type: FeedbackApiFailureType.server,
        );
      }

      return submission;
    } on TimeoutException {
      throw const FeedbackApiException(
        'The feedback service took too long to respond.',
        type: FeedbackApiFailureType.offline,
      );
    } on FeedbackApiException {
      rethrow;
    } catch (_) {
      throw const FeedbackApiException(
        'Unable to reach the feedback service right now.',
        type: FeedbackApiFailureType.offline,
      );
    }
  }

  FeedbackAvailability? _availabilityFromPayload(
    Map<String, dynamic>? payload,
  ) {
    final rawAvailability = payload?['availability'];
    if (rawAvailability is Map<String, dynamic>) {
      return FeedbackAvailability(
        isReachable: rawAvailability['isReachable'] as bool? ?? true,
        isConfigured: rawAvailability['isConfigured'] as bool? ?? false,
        label: rawAvailability['label'] as String? ?? 'Unavailable',
        message: rawAvailability['message'] as String?,
      );
    }
    if (rawAvailability is Map) {
      final availability = Map<String, dynamic>.from(rawAvailability);
      return FeedbackAvailability(
        isReachable: availability['isReachable'] as bool? ?? true,
        isConfigured: availability['isConfigured'] as bool? ?? false,
        label: availability['label'] as String? ?? 'Unavailable',
        message: availability['message'] as String?,
      );
    }

    return null;
  }

  FeedbackSubmissionResult? _submissionFromPayload(
    Map<String, dynamic>? payload,
  ) {
    final rawSubmission = payload?['submission'];
    if (rawSubmission is Map<String, dynamic>) {
      return FeedbackSubmissionResult.fromJson(rawSubmission);
    }
    if (rawSubmission is Map) {
      return FeedbackSubmissionResult.fromJson(
        Map<String, dynamic>.from(rawSubmission),
      );
    }

    return null;
  }

  Map<String, dynamic>? _decodeJsonMap(String body) {
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

enum FeedbackApiFailureType {
  offline,
  unavailable,
  invalidRequest,
  unauthorized,
  server,
  unknown,
}

class FeedbackApiException implements Exception {
  const FeedbackApiException(
    this.message, {
    this.type = FeedbackApiFailureType.unknown,
  });

  final String message;
  final FeedbackApiFailureType type;

  bool get isRetryable =>
      type == FeedbackApiFailureType.offline ||
      type == FeedbackApiFailureType.unavailable ||
      type == FeedbackApiFailureType.server ||
      type == FeedbackApiFailureType.unknown;

  @override
  String toString() => message;
}
