import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feedback_models.dart';
import '../services/feedback_admin_api.dart';
import '../services/burgerium_haptics.dart';
import '../services/feedback_api_client.dart';
import '../services/feedback_draft_store.dart';
import 'admin_access_screen.dart';
import '../theme/app_theme.dart';

enum _OverflowAction { admin, refresh, clear }

class FeedbackHomeScreen extends StatefulWidget {
  const FeedbackHomeScreen({
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
  State<FeedbackHomeScreen> createState() => _FeedbackHomeScreenState();
}

class _FeedbackHomeScreenState extends State<FeedbackHomeScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _commentsController;

  FeedbackDraft _draft = const FeedbackDraft();
  FeedbackAvailability _availability = const FeedbackAvailability.offline();
  FeedbackSubmissionResult? _lastSubmission;
  List<QueuedFeedbackSubmission> _pendingSubmissions =
      const <QueuedFeedbackSubmission>[];
  AdminSessionCredentials? _adminSession;
  bool _isBootstrapping = true;
  bool _isHydrating = false;
  bool _isSubmitting = false;
  bool _isRefreshingStatus = false;
  bool _isFlushingPendingSubmissions = false;
  int _activeStep = 0;

  int get _detailsStep => feedbackCategories.length;

  bool get _isDetailsStep => _activeStep == _detailsStep;

  bool get _canGoForwardFromQuestion =>
      !_isDetailsStep &&
      _draft.ratings.containsKey(feedbackCategories[_activeStep].key);

  bool get _canSubmitNow =>
      _draft.completedRatings == feedbackCategories.length &&
      _nameController.text.trim().length >= 2 &&
      RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim()) &&
      !_isSubmitting;

  int get _pendingSubmissionCount => _pendingSubmissions.length;

  String get _submitActionLabel {
    if (!_availability.isReachable || !_availability.isConfigured) {
      return 'Queue response';
    }
    return 'Submit feedback';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _commentsController = TextEditingController();

    _nameController.addListener(_syncDraftFromTextControllers);
    _phoneController.addListener(_syncDraftFromTextControllers);
    _commentsController.addListener(_syncDraftFromTextControllers);

    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final savedDraft = await widget.draftStore.readDraft();
    final pendingSubmissions = await widget.draftStore.readPendingSubmissions();
    if (!mounted) return;

    _applyDraftToControllers(savedDraft);

    setState(() {
      _draft = savedDraft;
      _pendingSubmissions = pendingSubmissions;
      _activeStep = _firstIncompleteStep(savedDraft);
      _isBootstrapping = false;
    });

    unawaited(_refreshAvailability(silent: true));
  }

  void _applyDraftToControllers(FeedbackDraft draft) {
    _isHydrating = true;
    _nameController.text = draft.name;
    _phoneController.text = draft.phone;
    _commentsController.text = draft.comments;
    _isHydrating = false;
  }

  void _syncDraftFromTextControllers() {
    if (_isHydrating) return;

    final nextDraft = _draft.copyWith(
      name: _nameController.text,
      phone: _phoneController.text,
      comments: _commentsController.text,
    );

    setState(() {
      _draft = nextDraft;
    });

    unawaited(widget.draftStore.saveDraft(nextDraft));
  }

  int _firstIncompleteStep(FeedbackDraft draft) {
    for (var index = 0; index < feedbackCategories.length; index++) {
      if (!draft.ratings.containsKey(feedbackCategories[index].key)) {
        return index;
      }
    }

    return _detailsStep;
  }

  int _nextIncompleteStep(int startIndex, FeedbackDraft draft) {
    for (var index = startIndex; index < feedbackCategories.length; index++) {
      if (!draft.ratings.containsKey(feedbackCategories[index].key)) {
        return index;
      }
    }

    for (
      var index = 0;
      index < startIndex && index < feedbackCategories.length;
      index++
    ) {
      if (!draft.ratings.containsKey(feedbackCategories[index].key)) {
        return index;
      }
    }

    return _detailsStep;
  }

  Future<void> _refreshAvailability({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isRefreshingStatus = true;
      });
    }

    final availability = await widget.api.fetchAvailability();
    if (!mounted) return;

    setState(() {
      _availability = availability;
      _isRefreshingStatus = false;
    });

    if (availability.isReachable &&
        availability.isConfigured &&
        _pendingSubmissions.isNotEmpty) {
      unawaited(_flushPendingSubmissions(showSnack: !silent));
    }
  }

  Future<void> _jumpToStep(int step) async {
    if (step < 0 || step > _detailsStep) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _activeStep = step;
    });

    await BurgeriumHaptics.selection();
  }

  Future<void> _goBack() async {
    if (_activeStep == 0) return;
    await _jumpToStep(_activeStep - 1);
  }

  Future<void> _goForward() async {
    if (!_canGoForwardFromQuestion) return;
    await _jumpToStep(_activeStep + 1);
  }

  Future<void> _selectRating(String categoryKey, int value) async {
    final categoryIndex = feedbackCategories.indexWhere(
      (category) => category.key == categoryKey,
    );
    if (categoryIndex == -1) return;

    final nextRatings = Map<String, int>.from(_draft.ratings)
      ..[categoryKey] = value;
    final nextDraft = _draft.copyWith(ratings: nextRatings);
    final nextStep = _nextIncompleteStep(categoryIndex + 1, nextDraft);

    setState(() {
      _draft = nextDraft;
      _activeStep = nextStep;
    });

    unawaited(widget.draftStore.saveDraft(nextDraft));
    await BurgeriumHaptics.selection();
  }

  Future<void> _toggleConsent(bool value) async {
    final nextDraft = _draft.copyWith(contactConsent: value);
    setState(() {
      _draft = nextDraft;
    });
    unawaited(widget.draftStore.saveDraft(nextDraft));
    await BurgeriumHaptics.soft();
  }

  Future<void> _applyQuickComment(String suggestion) async {
    final current = _commentsController.text.trim();
    final updated = current.isEmpty
        ? suggestion
        : current.contains(suggestion)
        ? current
        : '$current\n$suggestion';

    _commentsController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );

    await BurgeriumHaptics.soft();
  }

  Future<void> _clearDraft() async {
    await widget.draftStore.clearDraft();
    _applyDraftToControllers(const FeedbackDraft());

    setState(() {
      _draft = const FeedbackDraft();
      _activeStep = 0;
      _lastSubmission = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft cleared.')));
  }

  Future<void> _setPendingSubmissions(
    List<QueuedFeedbackSubmission> queue,
  ) async {
    await widget.draftStore.savePendingSubmissions(queue);
    if (!mounted) return;

    setState(() {
      _pendingSubmissions = queue;
    });
  }

  FeedbackAvailability _availabilityForFailure(FeedbackApiException error) {
    switch (error.type) {
      case FeedbackApiFailureType.offline:
        return FeedbackAvailability.offline(message: error.message);
      case FeedbackApiFailureType.unavailable:
        return FeedbackAvailability(
          isReachable: true,
          isConfigured: false,
          label: 'Temporarily unavailable',
          message: error.message,
        );
      case FeedbackApiFailureType.invalidRequest:
      case FeedbackApiFailureType.unauthorized:
      case FeedbackApiFailureType.server:
      case FeedbackApiFailureType.unknown:
        return _availability;
    }
  }

  Future<void> _queueSubmissionForLater(
    FeedbackDraft draft,
    String reason,
  ) async {
    final queuedAt = DateTime.now();
    final queuedSubmission = QueuedFeedbackSubmission(
      id: 'queued-${queuedAt.microsecondsSinceEpoch}',
      draft: draft,
      queuedAt: queuedAt,
      lastError: reason,
    );

    final nextQueue = <QueuedFeedbackSubmission>[
      ..._pendingSubmissions,
      queuedSubmission,
    ];

    await _setPendingSubmissions(nextQueue);
    await widget.draftStore.clearDraft();
    await BurgeriumHaptics.success();

    if (!mounted) return;

    _applyDraftToControllers(const FeedbackDraft());

    setState(() {
      _draft = const FeedbackDraft();
      _activeStep = 0;
      _lastSubmission = FeedbackSubmissionResult(
        id: queuedSubmission.id,
        name: draft.name.trim(),
        createdAt: queuedAt,
        compositeScore: draft.averageScore ?? 0,
        compositeLabel: draft.sentimentLabel,
        isQueued: true,
      );
      _isSubmitting = false;
    });
  }

  Future<void> _flushPendingSubmissions({bool showSnack = true}) async {
    if (_isFlushingPendingSubmissions || _pendingSubmissions.isEmpty) return;

    setState(() {
      _isFlushingPendingSubmissions = true;
    });

    var queue = List<QueuedFeedbackSubmission>.from(_pendingSubmissions);
    var deliveredCount = 0;
    var droppedCount = 0;

    for (final submission in List<QueuedFeedbackSubmission>.from(queue)) {
      try {
        await widget.api.submitFeedback(submission.draft);
        queue.removeWhere((entry) => entry.id == submission.id);
        deliveredCount += 1;
      } on FeedbackApiException catch (error) {
        if (!error.isRetryable) {
          queue.removeWhere((entry) => entry.id == submission.id);
          droppedCount += 1;
          continue;
        }

        if (mounted) {
          setState(() {
            _availability = _availabilityForFailure(error);
          });
        }

        queue = queue
            .map(
              (entry) => entry.id == submission.id
                  ? entry.copyWith(
                      attemptCount: entry.attemptCount + 1,
                      lastError: error.message,
                    )
                  : entry,
            )
            .toList(growable: false);
        break;
      } catch (error) {
        queue = queue
            .map(
              (entry) => entry.id == submission.id
                  ? entry.copyWith(
                      attemptCount: entry.attemptCount + 1,
                      lastError: error.toString(),
                    )
                  : entry,
            )
            .toList(growable: false);
        break;
      }
    }

    await _setPendingSubmissions(queue);
    if (!mounted) return;

    setState(() {
      _isFlushingPendingSubmissions = false;
    });

    if (!showSnack) return;

    if (deliveredCount > 0) {
      _showSnack(
        deliveredCount == 1
            ? '1 queued response sent.'
            : '$deliveredCount queued responses sent.',
      );
    } else if (droppedCount > 0) {
      _showSnack(
        droppedCount == 1
            ? '1 queued response was removed because the server rejected it.'
            : '$droppedCount queued responses were removed because the server rejected them.',
      );
    }
  }

  String? _validateName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Enter your name.';
    if (trimmed.length < 2) {
      return 'Enter at least 2 characters.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = (value ?? '').trim();

    if (trimmed.isEmpty) return 'Enter your 10-digit phone number.';

    if (!RegExp(r'^\d{10}$').hasMatch(trimmed)) {
      return 'Enter exactly 10 digits.';
    }

    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final missingCategoryKeys = _draft.missingCategoryKeys;
    if (missingCategoryKeys.isNotEmpty) {
      setState(() {
        _activeStep = _firstIncompleteStep(_draft);
      });
      await BurgeriumHaptics.error();
      _showSnack('Finish the remaining ratings before sending.');
      return;
    }

    final detailsValid = _formKey.currentState?.validate() ?? false;
    if (!detailsValid) {
      await BurgeriumHaptics.error();
      _showSnack('Check the details and try again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await BurgeriumHaptics.submit();

    final submissionDraft = _draft.copyWith(
      name: _nameController.text,
      phone: _phoneController.text,
      comments: _commentsController.text,
    );

    try {
      final result = await widget.api.submitFeedback(submissionDraft);

      await widget.draftStore.clearDraft();
      await BurgeriumHaptics.success();

      if (!mounted) return;

      _applyDraftToControllers(const FeedbackDraft());

      setState(() {
        _draft = const FeedbackDraft();
        _activeStep = 0;
        _lastSubmission = result;
        _isSubmitting = false;
      });

      if (_pendingSubmissions.isNotEmpty) {
        unawaited(_flushPendingSubmissions());
      }
    } catch (error) {
      if (error is FeedbackApiException && error.isRetryable) {
        if (mounted) {
          setState(() {
            _availability = _availabilityForFailure(error);
          });
        }
        await _queueSubmissionForLater(submissionDraft, error.message);
        return;
      }

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      await BurgeriumHaptics.error();
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAdminDashboard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AdminAccessScreen(
          api: widget.adminApi,
          initialSession: _adminSession,
          onSessionChanged: (session) {
            if (!mounted) return;
            setState(() {
              _adminSession = session;
            });
          },
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(_OverflowAction action) async {
    switch (action) {
      case _OverflowAction.admin:
        await _openAdminDashboard();
        break;
      case _OverflowAction.refresh:
        await _refreshAvailability(silent: false);
        break;
      case _OverflowAction.clear:
        await _clearDraft();
        break;
    }
  }

  Widget _buildStepContent(bool wideLayout) {
    final child = _isDetailsStep
        ? Form(
            key: _formKey,
            child: _DetailsStepView(
              key: const ValueKey<String>('details'),
              draft: _draft,
              nameController: _nameController,
              phoneController: _phoneController,
              commentsController: _commentsController,
              bottomSpacing: wideLayout ? 24 : 120,
              onToggleConsent: _toggleConsent,
              onQuickComment: _applyQuickComment,
              onJumpToStep: _jumpToStep,
              validateName: _validateName,
              validatePhone: _validatePhone,
            ),
          )
        : _QuestionStepView(
            key: ValueKey<String>(
              'question-${feedbackCategories[_activeStep].key}',
            ),
            category: feedbackCategories[_activeStep],
            step: _activeStep + 1,
            totalSteps: feedbackCategories.length,
            selectedValue: _draft.ratings[feedbackCategories[_activeStep].key],
            sentimentLabel: _draft.sentimentLabel,
            canGoBack: _activeStep > 0,
            canGoForward: _canGoForwardFromQuestion,
            onBack: _goBack,
            onForward: _goForward,
            onSelect: (value) =>
                _selectRating(feedbackCategories[_activeStep].key, value),
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          wideLayout ? 8 : 20,
          20,
          wideLayout ? 8 : 20,
          20,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wideLayout = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: _lastSubmission == null && _activeStep > 0
            ? IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(_lastSubmission == null ? 'Rate your visit' : 'Thank you'),
        actions: <Widget>[
          PopupMenuButton<_OverflowAction>(
            onSelected: (value) => unawaited(_handleMenuAction(value)),
            itemBuilder: (context) => <PopupMenuEntry<_OverflowAction>>[
              const PopupMenuItem<_OverflowAction>(
                value: _OverflowAction.admin,
                child: Text('Admin dashboard'),
              ),
              if (_lastSubmission == null &&
                  !wideLayout) ...<PopupMenuEntry<_OverflowAction>>[
                const PopupMenuDivider(),
                PopupMenuItem<_OverflowAction>(
                  value: _OverflowAction.refresh,
                  enabled: !_isRefreshingStatus,
                  child: Text(
                    _isRefreshingStatus ? 'Checking...' : 'Refresh status',
                  ),
                ),
                const PopupMenuItem<_OverflowAction>(
                  value: _OverflowAction.clear,
                  child: Text('Clear draft'),
                ),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: _lastSubmission != null || wideLayout
          ? null
          : _PhoneBottomBar(
              isDetailsStep: _isDetailsStep,
              canGoBack: _activeStep > 0,
              canGoForward: _canGoForwardFromQuestion,
              canSubmit: _canSubmitNow,
              isSubmitting: _isSubmitting,
              submitLabel: _submitActionLabel,
              onBack: _goBack,
              onForward: _goForward,
              onSubmit: _submit,
            ),
      body: _isBootstrapping
          ? const Center(
              child: CircularProgressIndicator(color: AppPalette.emberDeep),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _lastSubmission != null
                  ? _SuccessView(
                      key: const ValueKey<String>('success'),
                      result: _lastSubmission!,
                      onCollectAnother: () {
                        setState(() {
                          _lastSubmission = null;
                          _activeStep = 0;
                        });
                      },
                    )
                  : wideLayout
                  ? _WideCaptureLayout(
                      key: const ValueKey<String>('capture-wide'),
                      header: _ProgressHeader(
                        activeStep: _activeStep,
                        detailsStep: _detailsStep,
                        availability: _availability,
                        pendingSubmissionCount: _pendingSubmissionCount,
                        isFlushingPendingSubmissions:
                            _isFlushingPendingSubmissions,
                      ),
                      rail: _TabletSummaryRail(
                        draft: _draft,
                        activeStep: _activeStep,
                        availability: _availability,
                        pendingSubmissionCount: _pendingSubmissionCount,
                        isSubmitting: _isSubmitting,
                        isRefreshingStatus: _isRefreshingStatus,
                        isFlushingPendingSubmissions:
                            _isFlushingPendingSubmissions,
                        submitLabel: _submitActionLabel,
                        onJumpToStep: _jumpToStep,
                        onRefreshStatus: () =>
                            _refreshAvailability(silent: false),
                        onClear: _clearDraft,
                        onSubmit: _submit,
                      ),
                      content: _buildStepContent(true),
                    )
                  : _NarrowCaptureLayout(
                      key: const ValueKey<String>('capture-narrow'),
                      header: _ProgressHeader(
                        activeStep: _activeStep,
                        detailsStep: _detailsStep,
                        availability: _availability,
                        pendingSubmissionCount: _pendingSubmissionCount,
                        isFlushingPendingSubmissions:
                            _isFlushingPendingSubmissions,
                      ),
                      content: _buildStepContent(false),
                    ),
            ),
    );
  }
}

class _NarrowCaptureLayout extends StatelessWidget {
  const _NarrowCaptureLayout({
    super.key,
    required this.header,
    required this.content,
  });

  final Widget header;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: header,
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _WideCaptureLayout extends StatelessWidget {
  const _WideCaptureLayout({
    super.key,
    required this.header,
    required this.rail,
    required this.content,
  });

  final Widget header;
  final Widget rail;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 320, child: rail),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                header,
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.activeStep,
    required this.detailsStep,
    required this.availability,
    required this.pendingSubmissionCount,
    required this.isFlushingPendingSubmissions,
  });

  final int activeStep;
  final int detailsStep;
  final FeedbackAvailability availability;
  final int pendingSubmissionCount;
  final bool isFlushingPendingSubmissions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSteps = detailsStep + 1;
    final isDetailsStep = activeStep == detailsStep;
    final progress = (activeStep + 1) / totalSteps;
    final hasPendingSubmissions = pendingSubmissionCount > 0;
    final showWarning =
        hasPendingSubmissions ||
        !availability.isReachable ||
        !availability.isConfigured;
    final pendingLabel = pendingSubmissionCount == 1
        ? '1 queued response'
        : '$pendingSubmissionCount queued responses';
    final statusText = hasPendingSubmissions
        ? availability.isReachable && availability.isConfigured
              ? isFlushingPendingSubmissions
                    ? 'Sending $pendingLabel now.'
                    : '$pendingLabel will send automatically.'
              : pendingSubmissionCount == 1
              ? '$pendingLabel is saved on this device and will send automatically when the connection returns.'
              : '$pendingLabel are saved on this device and will send automatically when the connection returns.'
        : !availability.isReachable
        ? 'Offline. Completed reviews will queue on this device and send automatically when the connection returns.'
        : !availability.isConfigured
        ? 'Sending is unavailable right now. Completed reviews will stay queued on this device.'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isDetailsStep
              ? 'Review and send'
              : 'Question ${activeStep + 1} of $detailsStep',
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppPalette.emberDeep,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppPalette.outline,
            valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.ember),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (var index = 0; index < totalSteps; index++) ...<Widget>[
              _StepDot(
                isActive: index == activeStep,
                isComplete: index < activeStep,
              ),
              if (index != totalSteps - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        if (showWarning && statusText != null) ...<Widget>[
          const SizedBox(height: 12),
          _StatusNotice(message: statusText),
        ],
      ],
    );
  }
}

class _QuestionStepView extends StatelessWidget {
  const _QuestionStepView({
    super.key,
    required this.category,
    required this.step,
    required this.totalSteps,
    required this.selectedValue,
    required this.sentimentLabel,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onSelect,
  });

  final FeedbackCategory category;
  final int step;
  final int totalSteps;
  final int? selectedValue;
  final String sentimentLabel;
  final bool canGoBack;
  final bool canGoForward;
  final Future<void> Function() onBack;
  final Future<void> Function() onForward;
  final Future<void> Function(int value) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;

        if (velocity <= -220 && canGoForward) {
          onForward();
        } else if (velocity >= 220 && canGoBack) {
          onBack();
        }
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _InlineStepBadge(label: 'Step $step of $totalSteps'),
                const SizedBox(width: 8),
                _InlineStepBadge(label: sentimentLabel),
              ],
            ),
            const SizedBox(height: 12),
            Text(category.label, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(category.prompt, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 6),
            Text(
              canGoForward
                  ? 'Tap a score or swipe left for the next step.'
                  : 'Tap a score to continue.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppPalette.emberDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            for (final option in feedbackOptions) ...<Widget>[
              _RatingOptionTile(
                option: option,
                selected: option.value == selectedValue,
                highlight: category.highlight,
                onTap: () => onSelect(option.value),
              ),
              if (option != feedbackOptions.last) const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RatingOptionTile extends StatelessWidget {
  const _RatingOptionTile({
    required this.option,
    required this.selected,
    required this.highlight,
    required this.onTap,
  });

  final FeedbackOption option;
  final bool selected;
  final Color highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.9)
                  : AppPalette.outline,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: highlight.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(option.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(option.caption, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${option.value}/5',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppPalette.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppPalette.emberDeep : AppPalette.inkSoft,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsStepView extends StatelessWidget {
  const _DetailsStepView({
    super.key,
    required this.draft,
    required this.nameController,
    required this.phoneController,
    required this.commentsController,
    required this.bottomSpacing,
    required this.onToggleConsent,
    required this.onQuickComment,
    required this.onJumpToStep,
    required this.validateName,
    required this.validatePhone,
  });

  final FeedbackDraft draft;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController commentsController;
  final double bottomSpacing;
  final Future<void> Function(bool value) onToggleConsent;
  final Future<void> Function(String comment) onQuickComment;
  final Future<void> Function(int step) onJumpToStep;
  final String? Function(String? value) validateName;
  final String? Function(String? value) validatePhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              _InlineStepBadge(label: 'Final step'),
              SizedBox(width: 8),
              _InlineStepBadge(label: 'Name and phone required'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Anything else?', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter your name and phone number to submit a genuine review.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (var index = 0; index < feedbackCategories.length; index++)
                _AnswerChip(
                  label: feedbackCategories[index].shortLabel,
                  value: feedbackOptionForValue(
                    draft.ratings[feedbackCategories[index].key] ?? 3,
                  ).label,
                  onTap: () => onJumpToStep(index),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(80),
            ],
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Your name',
            ),
            validator: validateName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '10-digit phone number',
            ),
            validator: validatePhone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: commentsController,
            minLines: 4,
            maxLines: 6,
            maxLength: 600,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'Tell us what stood out.',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickCommentSuggestions
                .map(
                  (comment) => ActionChip(
                    label: Text(comment),
                    onPressed: () => onQuickComment(comment),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: const Text('Contact me about this visit'),
              subtitle: const Text('Turn this on only if you want a callback.'),
              value: draft.contactConsent,
              onChanged: (value) => onToggleConsent(value),
            ),
          ),
          SizedBox(height: bottomSpacing),
        ],
      ),
    );
  }
}

class _TabletSummaryRail extends StatelessWidget {
  const _TabletSummaryRail({
    required this.draft,
    required this.activeStep,
    required this.availability,
    required this.pendingSubmissionCount,
    required this.isSubmitting,
    required this.isRefreshingStatus,
    required this.isFlushingPendingSubmissions,
    required this.submitLabel,
    required this.onJumpToStep,
    required this.onRefreshStatus,
    required this.onClear,
    required this.onSubmit,
  });

  final FeedbackDraft draft;
  final int activeStep;
  final FeedbackAvailability availability;
  final int pendingSubmissionCount;
  final bool isSubmitting;
  final bool isRefreshingStatus;
  final bool isFlushingPendingSubmissions;
  final String submitLabel;
  final Future<void> Function(int step) onJumpToStep;
  final Future<void> Function() onRefreshStatus;
  final Future<void> Function() onClear;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sendReady = draft.completedRatings == feedbackCategories.length;
    final statusLabel = !availability.isReachable
        ? 'Offline'
        : availability.isConfigured
        ? 'Ready'
        : 'Unavailable';
    final queueLabel = pendingSubmissionCount == 1
        ? '1 queued response'
        : '$pendingSubmissionCount queued responses';

    return SingleChildScrollView(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Progress', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '${draft.completedRatings} of ${feedbackCategories.length} answered',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: draft.progress,
                  minHeight: 8,
                  backgroundColor: AppPalette.outline,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppPalette.ember,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Status: $statusLabel', style: theme.textTheme.bodyMedium),
              if (pendingSubmissionCount > 0) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  isFlushingPendingSubmissions
                      ? 'Queue: sending $queueLabel'
                      : 'Queue: $queueLabel on this device',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppPalette.emberDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              for (
                var index = 0;
                index < feedbackCategories.length;
                index++
              ) ...<Widget>[
                _RailStepTile(
                  label: feedbackCategories[index].shortLabel,
                  value: draft.ratings[feedbackCategories[index].key] == null
                      ? 'Waiting'
                      : feedbackOptionForValue(
                          draft.ratings[feedbackCategories[index].key]!,
                        ).label,
                  isActive: activeStep == index,
                  isComplete:
                      draft.ratings[feedbackCategories[index].key] != null,
                  onTap: () => onJumpToStep(index),
                ),
                if (index != feedbackCategories.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              _RailStepTile(
                label: 'Send',
                value: sendReady ? 'Ready' : 'Locked',
                isActive: activeStep == feedbackCategories.length,
                isComplete: sendReady,
                onTap: sendReady
                    ? () => onJumpToStep(feedbackCategories.length)
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: sendReady && !isSubmitting ? onSubmit : null,
                  child: Text(isSubmitting ? 'Sending...' : submitLabel),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isRefreshingStatus ? null : onRefreshStatus,
                      child: Text(
                        isRefreshingStatus ? 'Checking...' : 'Refresh status',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onClear,
                      child: const Text('Clear draft'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailStepTile extends StatelessWidget {
  const _RailStepTile({
    required this.label,
    required this.value,
    required this.isActive,
    required this.isComplete,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isActive;
  final bool isComplete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isActive
        ? AppPalette.ember.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.8);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppPalette.ember
                  : isComplete
                  ? AppPalette.ember.withValues(alpha: 0.36)
                  : AppPalette.outline,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                isComplete ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isComplete ? AppPalette.emberDeep : AppPalette.inkSoft,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppPalette.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Text(message),
    );
  }
}

class _InlineStepBadge extends StatelessWidget {
  const _InlineStepBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppPalette.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.isActive, required this.isComplete});

  final bool isActive;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppPalette.ember
        : isComplete
        ? AppPalette.ember.withValues(alpha: 0.5)
        : AppPalette.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: isActive ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PhoneBottomBar extends StatelessWidget {
  const _PhoneBottomBar({
    required this.isDetailsStep,
    required this.canGoBack,
    required this.canGoForward,
    required this.canSubmit,
    required this.isSubmitting,
    required this.submitLabel,
    required this.onBack,
    required this.onForward,
    required this.onSubmit,
  });

  final bool isDetailsStep;
  final bool canGoBack;
  final bool canGoForward;
  final bool canSubmit;
  final bool isSubmitting;
  final String submitLabel;
  final Future<void> Function() onBack;
  final Future<void> Function() onForward;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          border: Border(top: BorderSide(color: AppPalette.outline)),
        ),
        child: Row(
          children: <Widget>[
            if (canGoBack) ...<Widget>[
              OutlinedButton(onPressed: onBack, child: const Text('Back')),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: isDetailsStep
                  ? FilledButton(
                      onPressed: canSubmit ? onSubmit : null,
                      child: Text(isSubmitting ? 'Sending...' : submitLabel),
                    )
                  : FilledButton(
                      onPressed: canGoForward ? onForward : null,
                      child: const Text('Next'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text('$label: $value'), onPressed: onTap);
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    super.key,
    required this.result,
    required this.onCollectAnother,
  });

  final FeedbackSubmissionResult result;
  final VoidCallback onCollectAnother;

  @override
  Widget build(BuildContext context) {
    final guestLabel = result.name.trim().isEmpty ? '' : ' ${result.name}';
    final accentColor = result.isQueued
        ? AppPalette.emberDeep
        : AppPalette.success;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.isQueued
                          ? Icons.schedule_send_rounded
                          : Icons.check_rounded,
                      size: 36,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    result.isQueued ? 'Saved$guestLabel' : 'Thanks$guestLabel',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.isQueued
                        ? 'This response is saved on this device and will send automatically when the connection returns.'
                        : 'Your feedback has been saved.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onCollectAnother,
                      child: Text(
                        result.isQueued
                            ? 'Collect another response'
                            : 'Submit another response',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
