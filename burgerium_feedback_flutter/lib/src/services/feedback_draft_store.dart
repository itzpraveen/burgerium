import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feedback_models.dart';

abstract class FeedbackDraftStore {
  Future<FeedbackDraft> readDraft();

  Future<void> saveDraft(FeedbackDraft draft);

  Future<void> clearDraft();

  Future<List<QueuedFeedbackSubmission>> readPendingSubmissions();

  Future<void> savePendingSubmissions(List<QueuedFeedbackSubmission> queue);
}

class SecureFeedbackDraftStore implements FeedbackDraftStore {
  SecureFeedbackDraftStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _draftKey = 'burgerium_feedback_draft_v2';
  static const _queueKey = 'burgerium_feedback_queue_v1';
  static const _legacyDraftKey = 'burgerium_feedback_draft_v1';
  static const _draftRetention = Duration(hours: 24);

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearDraft() => _storage.delete(key: _draftKey);

  @override
  Future<FeedbackDraft> readDraft() async {
    await _migrateLegacyDraftIfNeeded();

    final payload = await _readJsonMap(_draftKey);
    if (payload == null) {
      return const FeedbackDraft();
    }

    final updatedAt = DateTime.tryParse(payload['updatedAt'] as String? ?? '');
    if (updatedAt == null ||
        DateTime.now().difference(updatedAt) > _draftRetention) {
      await clearDraft();
      return const FeedbackDraft();
    }

    final rawDraft = payload['draft'];
    if (rawDraft is Map<String, dynamic>) {
      return FeedbackDraft.fromJson(rawDraft);
    }
    if (rawDraft is Map) {
      return FeedbackDraft.fromJson(Map<String, dynamic>.from(rawDraft));
    }

    return const FeedbackDraft();
  }

  @override
  Future<List<QueuedFeedbackSubmission>> readPendingSubmissions() async {
    final payload = await _readJsonMap(_queueKey);
    if (payload == null) {
      return const <QueuedFeedbackSubmission>[];
    }

    final rawItems = payload['items'];
    if (rawItems is! List) {
      await savePendingSubmissions(const <QueuedFeedbackSubmission>[]);
      return const <QueuedFeedbackSubmission>[];
    }

    final queue = <QueuedFeedbackSubmission>[];

    for (final item in rawItems) {
      if (item is Map<String, dynamic>) {
        queue.add(QueuedFeedbackSubmission.fromJson(item));
      } else if (item is Map) {
        queue.add(
          QueuedFeedbackSubmission.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    queue.sort((left, right) => left.queuedAt.compareTo(right.queuedAt));
    return queue;
  }

  @override
  Future<void> saveDraft(FeedbackDraft draft) async {
    if (draft.isEmpty) {
      await clearDraft();
      return;
    }

    await _storage.write(
      key: _draftKey,
      value: jsonEncode(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'draft': draft.toJson(),
      }),
    );
  }

  @override
  Future<void> savePendingSubmissions(
    List<QueuedFeedbackSubmission> queue,
  ) async {
    if (queue.isEmpty) {
      await _storage.delete(key: _queueKey);
      return;
    }

    final normalized = List<QueuedFeedbackSubmission>.from(queue)
      ..sort((left, right) => left.queuedAt.compareTo(right.queuedAt));

    await _storage.write(
      key: _queueKey,
      value: jsonEncode(<String, dynamic>{
        'items': normalized.map((entry) => entry.toJson()).toList(),
      }),
    );
  }

  Future<void> _migrateLegacyDraftIfNeeded() async {
    final existing = await _storage.read(key: _draftKey);
    if (existing != null && existing.isNotEmpty) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_legacyDraftKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = _decodeJsonMap(raw);
    if (decoded == null) {
      await preferences.remove(_legacyDraftKey);
      return;
    }

    await _storage.write(
      key: _draftKey,
      value: jsonEncode(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'draft': decoded,
      }),
    );

    await preferences.remove(_legacyDraftKey);
  }

  Future<Map<String, dynamic>?> _readJsonMap(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = _decodeJsonMap(raw);
    if (decoded == null) {
      await _storage.delete(key: key);
      return null;
    }

    return decoded;
  }

  Map<String, dynamic>? _decodeJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }
}
