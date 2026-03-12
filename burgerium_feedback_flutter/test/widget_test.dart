import 'package:burgerium_feedback_flutter/src/app.dart';
import 'package:burgerium_feedback_flutter/src/models/feedback_models.dart';
import 'package:burgerium_feedback_flutter/src/services/feedback_admin_api.dart';
import 'package:burgerium_feedback_flutter/src/services/feedback_api_client.dart';
import 'package:burgerium_feedback_flutter/src/services/feedback_draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedApi implements FeedbackApi {
  FeedbackAvailability availability = const FeedbackAvailability(
    isReachable: true,
    isConfigured: true,
    label: 'Ready',
  );
  int submissionCount = 0;
  final List<FeedbackDraft> submittedDrafts = <FeedbackDraft>[];

  @override
  Future<FeedbackAvailability> fetchAvailability() async => availability;

  @override
  Future<FeedbackSubmissionResult> submitFeedback(FeedbackDraft draft) async {
    submissionCount += 1;
    submittedDrafts.add(draft);

    return FeedbackSubmissionResult(
      id: 'submitted-$submissionCount',
      name: draft.name.trim(),
      createdAt: DateTime(2026, 3, 12, 12, submissionCount),
      compositeScore: draft.averageScore ?? 0,
      compositeLabel: draft.sentimentLabel,
    );
  }
}

class _MemoryStore implements FeedbackDraftStore {
  FeedbackDraft draft = const FeedbackDraft();
  List<QueuedFeedbackSubmission> queue = <QueuedFeedbackSubmission>[];

  @override
  Future<void> clearDraft() async {
    draft = const FeedbackDraft();
  }

  @override
  Future<FeedbackDraft> readDraft() async => draft;

  @override
  Future<List<QueuedFeedbackSubmission>> readPendingSubmissions() async =>
      List<QueuedFeedbackSubmission>.from(queue);

  @override
  Future<void> saveDraft(FeedbackDraft nextDraft) async {
    draft = nextDraft;
  }

  @override
  Future<void> savePendingSubmissions(
    List<QueuedFeedbackSubmission> nextQueue,
  ) async {
    queue = List<QueuedFeedbackSubmission>.from(nextQueue);
  }
}

class _FakeAdminApi implements FeedbackAdminApi {
  int fetchCount = 0;

  @override
  Future<AdminFeedbackDashboard> fetchDashboard({
    required String username,
    required String password,
  }) async {
    fetchCount += 1;

    return AdminFeedbackDashboard(
      summary: const AdminFeedbackSummary(
        totalResponses: 1,
        averageOverall: 4.5,
        averageComposite: 4.4,
        contactOptIns: 1,
        attentionNeeded: 0,
        latestEntryAt: null,
        storageLabel: 'Test storage',
        storageMode: 'file',
        categoryAverages: <String, double>{},
      ),
      submissions: const <AdminFeedbackSubmission>[],
    );
  }
}

void main() {
  Future<void> pumpFeedbackApp(
    WidgetTester tester, {
    required FeedbackApi api,
    required FeedbackAdminApi adminApi,
    FeedbackDraftStore? draftStore,
  }) async {
    await tester.pumpWidget(
      BurgeriumFeedbackApp(
        api: api,
        adminApi: adminApi,
        draftStore: draftStore ?? _MemoryStore(),
        baseUri: Uri.parse('https://www.burgerium.in/'),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openOverflowMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the simplified feedback flow', (tester) async {
    await pumpFeedbackApp(
      tester,
      api: _ScriptedApi(),
      adminApi: _FakeAdminApi(),
    );

    expect(find.text('Rate your visit'), findsOneWidget);
    expect(find.text('Overall rating'), findsOneWidget);
  });

  testWidgets('supports back and next navigation on phone', (tester) async {
    await pumpFeedbackApp(
      tester,
      api: _ScriptedApi(),
      adminApi: _FakeAdminApi(),
    );

    await tester.tap(find.text('Great'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Overall rating'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('keeps admin session for the current app session', (
    tester,
  ) async {
    final adminApi = _FakeAdminApi();

    await pumpFeedbackApp(tester, api: _ScriptedApi(), adminApi: adminApi);

    await openOverflowMenu(tester);
    await tester.tap(find.text('Admin dashboard'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Open dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback summary and guest details.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await openOverflowMenu(tester);
    await tester.tap(find.text('Admin dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback summary and guest details.'), findsOneWidget);
    expect(adminApi.fetchCount, greaterThanOrEqualTo(2));
  });

  testWidgets('restores a saved draft into the details step', (tester) async {
    final store = _MemoryStore()
      ..draft = FeedbackDraft(
        ratings: <String, int>{
          for (final category in feedbackCategories) category.key: 5,
        },
        name: 'Faisal',
        phone: '9447650870',
      );

    await pumpFeedbackApp(
      tester,
      api: _ScriptedApi(),
      adminApi: _FakeAdminApi(),
      draftStore: store,
    );

    expect(find.text('Anything else?'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Submit feedback'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Faisal',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '9447650870',
    );
  });
}
