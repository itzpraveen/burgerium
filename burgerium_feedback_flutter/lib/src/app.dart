import 'package:flutter/material.dart';

import 'screens/feedback_home_screen.dart';
import 'services/feedback_admin_api.dart';
import 'services/feedback_api_client.dart';
import 'services/feedback_draft_store.dart';
import 'theme/app_theme.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://www.burgerium.in/',
);

class BurgeriumFeedbackBootstrap extends StatelessWidget {
  const BurgeriumFeedbackBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final baseUri = Uri.parse(_defaultApiBaseUrl);

    return BurgeriumFeedbackApp(
      api: HttpFeedbackApi(baseUri: baseUri),
      adminApi: HttpFeedbackAdminApi(baseUri: baseUri),
      draftStore: SecureFeedbackDraftStore(),
      baseUri: baseUri,
    );
  }
}

class BurgeriumFeedbackApp extends StatelessWidget {
  const BurgeriumFeedbackApp({
    super.key,
    required this.api,
    required this.adminApi,
    required this.draftStore,
    required this.baseUri,
  });

  final FeedbackApi api;
  final FeedbackAdminApi adminApi;
  final FeedbackDraftStore draftStore;
  final Uri baseUri;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Burgerium Feedback',
      theme: buildBurgeriumTheme(),
      home: FeedbackHomeScreen(
        api: api,
        adminApi: adminApi,
        draftStore: draftStore,
        baseUri: baseUri,
      ),
    );
  }
}
