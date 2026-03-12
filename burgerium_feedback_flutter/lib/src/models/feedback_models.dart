import 'package:flutter/material.dart';

@immutable
class FeedbackCategory {
  const FeedbackCategory({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.prompt,
    required this.highlight,
  });

  final String key;
  final String label;
  final String shortLabel;
  final String prompt;
  final Color highlight;
}

@immutable
class FeedbackOption {
  const FeedbackOption({
    required this.value,
    required this.label,
    required this.emoji,
    required this.caption,
  });

  final int value;
  final String label;
  final String emoji;
  final String caption;
}

const feedbackCategories = <FeedbackCategory>[
  FeedbackCategory(
    key: 'overall',
    label: 'Overall rating',
    shortLabel: 'Overall',
    prompt: 'The full feeling after food, pace, and service came together.',
    highlight: Color(0xFFFFA63D),
  ),
  FeedbackCategory(
    key: 'food',
    label: 'Food',
    shortLabel: 'Food',
    prompt: 'Taste, temperature, freshness, and burger build.',
    highlight: Color(0xFFFFC85D),
  ),
  FeedbackCategory(
    key: 'service',
    label: 'Service',
    shortLabel: 'Service',
    prompt: 'Warmth, attentiveness, and clarity from the team.',
    highlight: Color(0xFFFF8B62),
  ),
  FeedbackCategory(
    key: 'onTime',
    label: 'Food on time?',
    shortLabel: 'On time',
    prompt: 'How the order timing felt from payment to first bite.',
    highlight: Color(0xFFFFB54D),
  ),
  FeedbackCategory(
    key: 'cleanlinessAmbience',
    label: 'Cleanliness & ambience',
    shortLabel: 'Ambience',
    prompt: 'Dining comfort, cleanliness, sound, and overall room feel.',
    highlight: Color(0xFFFF9766),
  ),
  FeedbackCategory(
    key: 'menuAvailability',
    label: 'Menu availability',
    shortLabel: 'Menu',
    prompt: 'How well the menu matched what was actually available.',
    highlight: Color(0xFFFFC248),
  ),
];

const feedbackOptions = <FeedbackOption>[
  FeedbackOption(value: 5, label: 'Great', emoji: '😍', caption: 'Loved it'),
  FeedbackOption(value: 4, label: 'Good', emoji: '😄', caption: 'Strong visit'),
  FeedbackOption(value: 3, label: 'Okay', emoji: '🙂', caption: 'Acceptable'),
  FeedbackOption(value: 2, label: 'Fair', emoji: '😐', caption: 'Below par'),
  FeedbackOption(value: 1, label: 'Poor', emoji: '😞', caption: 'Needs rescue'),
];

const quickCommentSuggestions = <String>[
  'The burger quality stood out.',
  'Service was quick and genuinely helpful.',
  'The order took longer than expected.',
  'The dining area felt clean and comfortable.',
  'Please contact me about this visit.',
];

const visitSignals = <String>[
  'Native Flutter haptics',
  'Phone and tablet tuned',
  'Draft stays on-device',
];

@immutable
class FeedbackDraft {
  const FeedbackDraft({
    this.ratings = const {},
    this.name = '',
    this.phone = '',
    this.comments = '',
    this.contactConsent = false,
  });

  final Map<String, int> ratings;
  final String name;
  final String phone;
  final String comments;
  final bool contactConsent;

  bool get isEmpty =>
      ratings.isEmpty &&
      name.trim().isEmpty &&
      phone.trim().isEmpty &&
      comments.trim().isEmpty &&
      !contactConsent;

  FeedbackDraft copyWith({
    Map<String, int>? ratings,
    String? name,
    String? phone,
    String? comments,
    bool? contactConsent,
  }) {
    return FeedbackDraft(
      ratings: ratings ?? this.ratings,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      comments: comments ?? this.comments,
      contactConsent: contactConsent ?? this.contactConsent,
    );
  }

  int get completedRatings => ratings.length;

  double get progress => completedRatings / feedbackCategories.length;

  double? get averageScore {
    if (ratings.isEmpty) return null;
    final total = ratings.values.fold<int>(0, (sum, score) => sum + score);
    return total / ratings.length;
  }

  String get sentimentLabel {
    final score = averageScore;
    if (score == null) return 'Warming up';
    if (score >= 4.5) return 'Loved it';
    if (score >= 3.5) return 'Strong visit';
    if (score >= 2.5) return 'Mixed signals';
    if (score >= 1.5) return 'Needs attention';
    return 'Recovery needed';
  }

  String get sentimentDescription {
    final score = averageScore;
    if (score == null) {
      return 'Start tapping through the table experience and the summary will sharpen itself.';
    }
    if (score >= 4.5) {
      return 'The guest is clearly happy. This is where follow-up can turn delight into loyalty.';
    }
    if (score >= 3.5) {
      return 'The visit landed well overall, with a few details that could still be tightened.';
    }
    if (score >= 2.5) {
      return 'The experience feels uneven. Comments matter here because they point to the real issue.';
    }
    return 'Something felt off. Act on this one fast if the guest wants a callback.';
  }

  List<String> get missingCategoryKeys {
    return feedbackCategories
        .where((category) => !ratings.containsKey(category.key))
        .map((category) => category.key)
        .toList(growable: false);
  }

  String? get firstMissingShortLabel {
    for (final category in feedbackCategories) {
      if (!ratings.containsKey(category.key)) return category.shortLabel;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ratings': ratings,
      'name': name,
      'phone': phone,
      'comments': comments,
      'contactConsent': contactConsent,
    };
  }

  Map<String, dynamic> toApiPayload() {
    return <String, dynamic>{
      for (final category in feedbackCategories)
        category.key: ratings[category.key],
      'name': name.trim(),
      'phone': phone.trim(),
      'comments': comments.trim(),
      'contactConsent': contactConsent,
    };
  }

  factory FeedbackDraft.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'];
    final ratings = <String, int>{};

    if (rawRatings is Map) {
      for (final entry in rawRatings.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key is String && value is num) {
          ratings[key] = value.toInt();
        }
      }
    }

    return FeedbackDraft(
      ratings: ratings,
      name: json['name'] is String ? json['name'] as String : '',
      phone: json['phone'] is String ? json['phone'] as String : '',
      comments: json['comments'] is String ? json['comments'] as String : '',
      contactConsent: json['contactConsent'] is bool
          ? json['contactConsent'] as bool
          : false,
    );
  }
}

@immutable
class FeedbackAvailability {
  const FeedbackAvailability({
    required this.isReachable,
    required this.isConfigured,
    required this.label,
    this.message,
  });

  const FeedbackAvailability.offline({this.message})
    : isReachable = false,
      isConfigured = false,
      label = 'Offline';

  final bool isReachable;
  final bool isConfigured;
  final String label;
  final String? message;

  String get headline {
    if (!isReachable) return 'Connection paused';
    if (isConfigured) return 'Ready to collect';
    return 'Storage needs attention';
  }

  String get detail {
    if (!isReachable) {
      return message ??
          'Completed reviews can queue on this device and send automatically once the connection is back.';
    }
    if (isConfigured) {
      return 'Submissions are ready to flow to the Burgerium feedback backend.';
    }
    return message ??
        'Feedback storage is not available on the server right now.';
  }
}

@immutable
class FeedbackSubmissionResult {
  const FeedbackSubmissionResult({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.compositeScore,
    required this.compositeLabel,
    this.isQueued = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final double compositeScore;
  final String compositeLabel;
  final bool isQueued;

  factory FeedbackSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmissionResult(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      compositeScore: (json['compositeScore'] as num?)?.toDouble() ?? 0,
      compositeLabel: json['compositeLabel'] as String? ?? 'Okay',
      isQueued: json['isQueued'] as bool? ?? false,
    );
  }
}

@immutable
class QueuedFeedbackSubmission {
  const QueuedFeedbackSubmission({
    required this.id,
    required this.draft,
    required this.queuedAt,
    this.attemptCount = 0,
    this.lastError,
  });

  final String id;
  final FeedbackDraft draft;
  final DateTime queuedAt;
  final int attemptCount;
  final String? lastError;

  QueuedFeedbackSubmission copyWith({
    FeedbackDraft? draft,
    DateTime? queuedAt,
    int? attemptCount,
    String? lastError,
  }) {
    return QueuedFeedbackSubmission(
      id: id,
      draft: draft ?? this.draft,
      queuedAt: queuedAt ?? this.queuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'draft': draft.toJson(),
      'queuedAt': queuedAt.toIso8601String(),
      'attemptCount': attemptCount,
      'lastError': lastError,
    };
  }

  factory QueuedFeedbackSubmission.fromJson(Map<String, dynamic> json) {
    final rawDraft = json['draft'];

    return QueuedFeedbackSubmission(
      id: json['id'] as String? ?? '',
      draft: rawDraft is Map<String, dynamic>
          ? FeedbackDraft.fromJson(rawDraft)
          : rawDraft is Map
          ? FeedbackDraft.fromJson(Map<String, dynamic>.from(rawDraft))
          : const FeedbackDraft(),
      queuedAt:
          DateTime.tryParse(json['queuedAt'] as String? ?? '') ??
          DateTime.now(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

FeedbackOption feedbackOptionForValue(int value) {
  for (final option in feedbackOptions) {
    if (option.value == value) return option;
  }

  return feedbackOptions[2];
}

@immutable
class AdminSessionCredentials {
  const AdminSessionCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

@immutable
class AdminFeedbackSummary {
  const AdminFeedbackSummary({
    required this.totalResponses,
    required this.averageOverall,
    required this.averageComposite,
    required this.contactOptIns,
    required this.attentionNeeded,
    required this.latestEntryAt,
    required this.storageLabel,
    required this.storageMode,
    required this.categoryAverages,
  });

  final int totalResponses;
  final double averageOverall;
  final double averageComposite;
  final int contactOptIns;
  final int attentionNeeded;
  final DateTime? latestEntryAt;
  final String storageLabel;
  final String storageMode;
  final Map<String, double> categoryAverages;

  factory AdminFeedbackSummary.fromJson(Map<String, dynamic> json) {
    final storageJson = json['storage'];
    final categoryJson = json['categoryAverages'];
    final categoryAverages = <String, double>{};

    if (categoryJson is Map) {
      for (final entry in categoryJson.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is num) {
          categoryAverages[key] = value.toDouble();
        }
      }
    }

    return AdminFeedbackSummary(
      totalResponses: (json['totalResponses'] as num?)?.toInt() ?? 0,
      averageOverall: (json['averageOverall'] as num?)?.toDouble() ?? 0,
      averageComposite: (json['averageComposite'] as num?)?.toDouble() ?? 0,
      contactOptIns: (json['contactOptIns'] as num?)?.toInt() ?? 0,
      attentionNeeded: (json['attentionNeeded'] as num?)?.toInt() ?? 0,
      latestEntryAt: DateTime.tryParse(json['latestEntryAt'] as String? ?? ''),
      storageLabel: storageJson is Map
          ? storageJson['label'] as String? ?? 'Unknown'
          : 'Unknown',
      storageMode: storageJson is Map
          ? storageJson['mode'] as String? ?? 'unknown'
          : 'unknown',
      categoryAverages: categoryAverages,
    );
  }
}

@immutable
class AdminFeedbackSubmission {
  const AdminFeedbackSubmission({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.phone,
    required this.comments,
    required this.contactConsent,
    required this.compositeScore,
    required this.compositeLabel,
    required this.ratings,
  });

  final String id;
  final DateTime createdAt;
  final String name;
  final String phone;
  final String comments;
  final bool contactConsent;
  final double compositeScore;
  final String compositeLabel;
  final Map<String, int> ratings;

  factory AdminFeedbackSubmission.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'];
    final ratings = <String, int>{};

    if (rawRatings is Map) {
      for (final entry in rawRatings.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key is String && value is num) {
          ratings[key] = value.toInt();
        }
      }
    }

    return AdminFeedbackSubmission(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      comments: json['comments'] as String? ?? '',
      contactConsent: json['contactConsent'] as bool? ?? false,
      compositeScore: (json['compositeScore'] as num?)?.toDouble() ?? 0,
      compositeLabel: json['compositeLabel'] as String? ?? 'Okay',
      ratings: ratings,
    );
  }
}

@immutable
class AdminFeedbackDashboard {
  const AdminFeedbackDashboard({
    required this.summary,
    required this.submissions,
  });

  final AdminFeedbackSummary summary;
  final List<AdminFeedbackSubmission> submissions;

  factory AdminFeedbackDashboard.fromJson(Map<String, dynamic> json) {
    final submissionsJson = json['submissions'];
    final submissions = <AdminFeedbackSubmission>[];

    if (submissionsJson is List) {
      for (final entry in submissionsJson) {
        if (entry is Map<String, dynamic>) {
          submissions.add(AdminFeedbackSubmission.fromJson(entry));
        } else if (entry is Map) {
          submissions.add(
            AdminFeedbackSubmission.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    final summaryJson = json['summary'];

    return AdminFeedbackDashboard(
      summary: summaryJson is Map<String, dynamic>
          ? AdminFeedbackSummary.fromJson(summaryJson)
          : summaryJson is Map
          ? AdminFeedbackSummary.fromJson(
              Map<String, dynamic>.from(summaryJson),
            )
          : const AdminFeedbackSummary(
              totalResponses: 0,
              averageOverall: 0,
              averageComposite: 0,
              contactOptIns: 0,
              attentionNeeded: 0,
              latestEntryAt: null,
              storageLabel: 'Unknown',
              storageMode: 'unknown',
              categoryAverages: <String, double>{},
            ),
      submissions: submissions,
    );
  }
}
