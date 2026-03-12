import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feedback_models.dart';
import '../services/feedback_admin_api.dart';
import '../theme/app_theme.dart';

class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({
    super.key,
    required this.api,
    required this.onSessionChanged,
    this.initialSession,
  });

  final FeedbackAdminApi api;
  final AdminSessionCredentials? initialSession;
  final ValueChanged<AdminSessionCredentials?> onSessionChanged;

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  AdminSessionCredentials? _activeSession;
  AdminFeedbackDashboard? _dashboard;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _activeSession = widget.initialSession;

    if (_activeSession != null) {
      _usernameController.text = _activeSession!.username;
      _passwordController.text = _activeSession!.password;
      _isLoading = true;
      unawaited(_loadDashboard(useSavedSession: true));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    FocusScope.of(context).unfocus();
    await _loadDashboard();
  }

  Future<void> _loadDashboard({bool useSavedSession = false}) async {
    final session = useSavedSession ? _activeSession : null;
    final username = session?.username ?? _usernameController.text;
    final password = session?.password ?? _passwordController.text;

    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _errorMessage = null;
    }

    try {
      final dashboard = await widget.api.fetchDashboard(
        username: username,
        password: password,
      );
      if (!mounted) return;

      final nextSession = AdminSessionCredentials(
        username: username.trim(),
        password: password,
      );
      _activeSession = nextSession;
      widget.onSessionChanged(nextSession);

      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      final message = error.toString();
      final invalidCredentials =
          message == 'Invalid admin username or password.';

      if (_dashboard != null && !invalidCredentials) {
        setState(() {
          _isLoading = false;
        });
        _showSnack(message);
        return;
      }

      if (invalidCredentials) {
        _activeSession = null;
        widget.onSessionChanged(null);
      }

      setState(() {
        _dashboard = null;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  void _logout() {
    FocusScope.of(context).unfocus();
    _activeSession = null;
    widget.onSessionChanged(null);
    setState(() {
      _dashboard = null;
      _errorMessage = null;
      _passwordController.clear();
      _obscurePassword = true;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSubmissionDetails(AdminFeedbackSubmission submission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return SafeArea(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: _SubmissionDetailSheet(submission: submission),
              ),
            );
          },
        );
      },
    );
  }

  String? _validateUsername(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter the admin username.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter the admin password.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E6),
      appBar: AppBar(
        title: Text(dashboard == null ? 'Admin login' : 'Feedback admin'),
        actions: dashboard == null
            ? null
            : <Widget>[
                IconButton(
                  tooltip: 'Refresh dashboard',
                  onPressed: _isLoading ? null : _loadDashboard,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Log out',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: dashboard == null
            ? _AdminLoginView(
                formKey: _formKey,
                usernameController: _usernameController,
                passwordController: _passwordController,
                isLoading: _isLoading,
                obscurePassword: _obscurePassword,
                errorMessage: _errorMessage,
                onSubmit: _login,
                onTogglePassword: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                validateUsername: _validateUsername,
                validatePassword: _validatePassword,
              )
            : _AdminDashboardView(
                dashboard: dashboard,
                isRefreshing: _isLoading,
                onRefresh: _loadDashboard,
                onOpenSubmission: _openSubmissionDetails,
              ),
      ),
    );
  }
}

class _AdminLoginView extends StatelessWidget {
  const _AdminLoginView({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.errorMessage,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.validateUsername,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final String? errorMessage;
  final Future<void> Function() onSubmit;
  final VoidCallback onTogglePassword;
  final String? Function(String?) validateUsername;
  final String? Function(String?) validatePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Operator access'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to view feedback summary.',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This uses the same protected admin credentials configured on the Burgerium website.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _InlineAlert(message: errorMessage!),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Admin username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: validateUsername,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Admin password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                      validator: validatePassword,
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : onSubmit,
                        icon: isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppPalette.ink,
                                ),
                              )
                            : const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(
                          isLoading ? 'Checking access...' : 'Open dashboard',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Credentials stay in memory only for this session and are cleared when you log out.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AdminDateFilter { all, today, last7Days, last30Days }

enum _AdminScoreFilter { all, fourPlus, threeOrBelow, attention }

class _AdminDashboardView extends StatefulWidget {
  const _AdminDashboardView({
    required this.dashboard,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onOpenSubmission,
  });

  final AdminFeedbackDashboard dashboard;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final ValueChanged<AdminFeedbackSubmission> onOpenSubmission;

  @override
  State<_AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<_AdminDashboardView> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  _AdminDateFilter _dateFilter = _AdminDateFilter.all;
  _AdminScoreFilter _scoreFilter = _AdminScoreFilter.all;
  bool _followUpOnly = false;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_searchQuery.isNotEmpty) count += 1;
    if (_dateFilter != _AdminDateFilter.all) count += 1;
    if (_scoreFilter != _AdminScoreFilter.all) count += 1;
    if (_followUpOnly) count += 1;
    return count;
  }

  void _setSearchQuery(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      _currentPage = 0;
    });
  }

  void _setDateFilter(_AdminDateFilter value) {
    setState(() {
      _dateFilter = value;
      _currentPage = 0;
    });
  }

  void _setScoreFilter(_AdminScoreFilter value) {
    setState(() {
      _scoreFilter = value;
      _currentPage = 0;
    });
  }

  void _setFollowUpOnly(bool value) {
    setState(() {
      _followUpOnly = value;
      _currentPage = 0;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _dateFilter = _AdminDateFilter.all;
      _scoreFilter = _AdminScoreFilter.all;
      _followUpOnly = false;
      _currentPage = 0;
    });
  }

  List<AdminFeedbackSubmission> _filteredSubmissions() {
    final nowIndia = _toIndiaTime(DateTime.now().toUtc());

    return widget.dashboard.submissions
        .where((submission) {
          final matchesSearch = _searchQuery.isEmpty
              ? true
              : <String>[
                  submission.name,
                  submission.phone,
                  submission.comments,
                  submission.compositeLabel,
                ].any((value) => value.toLowerCase().contains(_searchQuery));

          if (!matchesSearch) return false;
          if (_followUpOnly && !submission.contactConsent) return false;
          if (!_matchesDateFilter(submission, nowIndia)) return false;
          if (!_matchesScoreFilter(submission)) return false;

          return true;
        })
        .toList(growable: false);
  }

  bool _matchesDateFilter(
    AdminFeedbackSubmission submission,
    DateTime nowIndia,
  ) {
    if (_dateFilter == _AdminDateFilter.all) return true;

    final submissionIndia = _toIndiaTime(submission.createdAt);
    final submissionDay = DateTime(
      submissionIndia.year,
      submissionIndia.month,
      submissionIndia.day,
    );
    final currentDay = DateTime(nowIndia.year, nowIndia.month, nowIndia.day);

    switch (_dateFilter) {
      case _AdminDateFilter.all:
        return true;
      case _AdminDateFilter.today:
        return submissionDay == currentDay;
      case _AdminDateFilter.last7Days:
        return !submissionDay.isBefore(
          currentDay.subtract(const Duration(days: 6)),
        );
      case _AdminDateFilter.last30Days:
        return !submissionDay.isBefore(
          currentDay.subtract(const Duration(days: 29)),
        );
    }
  }

  bool _matchesScoreFilter(AdminFeedbackSubmission submission) {
    final overall = submission.ratings['overall'] ?? 0;

    switch (_scoreFilter) {
      case _AdminScoreFilter.all:
        return true;
      case _AdminScoreFilter.fourPlus:
        return submission.compositeScore >= 4;
      case _AdminScoreFilter.threeOrBelow:
        return submission.compositeScore <= 3;
      case _AdminScoreFilter.attention:
        return submission.compositeScore <= 2.5 || overall <= 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.dashboard.summary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= 960;
        final denseCards = !wideLayout;
        final pageSize = wideLayout ? 10 : 6;
        final filteredSubmissions = _filteredSubmissions();
        final pageCount = filteredSubmissions.isEmpty
            ? 1
            : ((filteredSubmissions.length - 1) ~/ pageSize) + 1;
        final currentPage = filteredSubmissions.isEmpty
            ? 0
            : _currentPage.clamp(0, pageCount - 1).toInt();
        final startIndex = filteredSubmissions.isEmpty
            ? 0
            : currentPage * pageSize;
        final endIndex = filteredSubmissions.isEmpty
            ? 0
            : (startIndex + pageSize).clamp(0, filteredSubmissions.length);
        final visibleSubmissions = filteredSubmissions.sublist(
          startIndex,
          endIndex,
        );

        return RefreshIndicator(
          color: AppPalette.emberDeep,
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              wideLayout ? 24 : 16,
              16,
              wideLayout ? 24 : 16,
              24,
            ),
            children: <Widget>[
              _DashboardHero(
                summary: summary,
                isRefreshing: widget.isRefreshing,
              ),
              const SizedBox(height: 16),
              _SummaryGrid(summary: summary, wideLayout: wideLayout),
              const SizedBox(height: 16),
              _CategoryAveragesCard(summary: summary),
              const SizedBox(height: 16),
              _SubmissionFiltersCard(
                searchController: _searchController,
                onSearchChanged: _setSearchQuery,
                dateFilter: _dateFilter,
                scoreFilter: _scoreFilter,
                followUpOnly: _followUpOnly,
                onDateFilterChanged: _setDateFilter,
                onScoreFilterChanged: _setScoreFilter,
                onFollowUpChanged: _setFollowUpOnly,
                activeFilterCount: _activeFilterCount,
                onClearFilters: _clearFilters,
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Recent submissions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    filteredSubmissions.isEmpty
                        ? '0 shown'
                        : '${startIndex + 1}-$endIndex of ${filteredSubmissions.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.dashboard.submissions.isEmpty)
                const _EmptyStateCard(
                  title: 'No feedback collected yet',
                  message: 'The first completed visit will appear here.',
                )
              else if (filteredSubmissions.isEmpty)
                const _EmptyStateCard(
                  title: 'No submissions match these filters',
                  message:
                      'Try widening the date range, score filter, or follow-up setting.',
                )
              else ...<Widget>[
                for (final submission in visibleSubmissions) ...<Widget>[
                  _SubmissionCard(
                    submission: submission,
                    dense: denseCards,
                    onOpen: () => widget.onOpenSubmission(submission),
                  ),
                  const SizedBox(height: 10),
                ],
                if (pageCount > 1) ...<Widget>[
                  const SizedBox(height: 6),
                  _PaginationBar(
                    currentPage: currentPage,
                    pageCount: pageCount,
                    onPrevious: currentPage == 0
                        ? null
                        : () {
                            setState(() {
                              _currentPage = currentPage - 1;
                            });
                          },
                    onNext: currentPage >= pageCount - 1
                        ? null
                        : () {
                            setState(() {
                              _currentPage = currentPage + 1;
                            });
                          },
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubmissionFiltersCard extends StatelessWidget {
  const _SubmissionFiltersCard({
    required this.searchController,
    required this.onSearchChanged,
    required this.dateFilter,
    required this.scoreFilter,
    required this.followUpOnly,
    required this.onDateFilterChanged,
    required this.onScoreFilterChanged,
    required this.onFollowUpChanged,
    required this.activeFilterCount,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final _AdminDateFilter dateFilter;
  final _AdminScoreFilter scoreFilter;
  final bool followUpOnly;
  final ValueChanged<_AdminDateFilter> onDateFilterChanged;
  final ValueChanged<_AdminScoreFilter> onScoreFilterChanged;
  final ValueChanged<bool> onFollowUpChanged;
  final int activeFilterCount;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Search and filter',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (activeFilterCount > 0)
                  TextButton(
                    onPressed: onClearFilters,
                    child: Text('Clear ($activeFilterCount)'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search guest, phone, or comment',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Text('Date', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: dateFilter == _AdminDateFilter.all,
                  onSelected: (_) => onDateFilterChanged(_AdminDateFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Today'),
                  selected: dateFilter == _AdminDateFilter.today,
                  onSelected: (_) =>
                      onDateFilterChanged(_AdminDateFilter.today),
                ),
                ChoiceChip(
                  label: const Text('Last 7 days'),
                  selected: dateFilter == _AdminDateFilter.last7Days,
                  onSelected: (_) =>
                      onDateFilterChanged(_AdminDateFilter.last7Days),
                ),
                ChoiceChip(
                  label: const Text('Last 30 days'),
                  selected: dateFilter == _AdminDateFilter.last30Days,
                  onSelected: (_) =>
                      onDateFilterChanged(_AdminDateFilter.last30Days),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Score', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: scoreFilter == _AdminScoreFilter.all,
                  onSelected: (_) =>
                      onScoreFilterChanged(_AdminScoreFilter.all),
                ),
                ChoiceChip(
                  label: const Text('4.0+'),
                  selected: scoreFilter == _AdminScoreFilter.fourPlus,
                  onSelected: (_) =>
                      onScoreFilterChanged(_AdminScoreFilter.fourPlus),
                ),
                ChoiceChip(
                  label: const Text('3.0 or below'),
                  selected: scoreFilter == _AdminScoreFilter.threeOrBelow,
                  onSelected: (_) =>
                      onScoreFilterChanged(_AdminScoreFilter.threeOrBelow),
                ),
                ChoiceChip(
                  label: const Text('Needs attention'),
                  selected: scoreFilter == _AdminScoreFilter.attention,
                  onSelected: (_) =>
                      onScoreFilterChanged(_AdminScoreFilter.attention),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilterChip(
              label: const Text('Follow-up requested only'),
              selected: followUpOnly,
              onSelected: onFollowUpChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Page ${currentPage + 1} of $pageCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous page',
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next page',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.summary, required this.isRefreshing});

  final AdminFeedbackSummary summary;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = summary.latestEntryAt == null
        ? 'No submissions yet'
        : _formatDateTime(context, summary.latestEntryAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Live dashboard'),
                ),
                if (isRefreshing) ...<Widget>[
                  const SizedBox(width: 10),
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.1,
                      color: AppPalette.emberDeep,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Feedback summary and guest details.',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Track the average visit score, spot low-scoring tables quickly, and open each submission for full notes and ratings.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Latest entry: $latest',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppPalette.emberDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.wideLayout});

  final AdminFeedbackSummary summary;
  final bool wideLayout;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, String caption})>[
      (
        label: 'Total responses',
        value: '${summary.totalResponses}',
        caption: 'All submitted visits',
      ),
      (
        label: 'Avg overall',
        value: '${summary.averageOverall.toStringAsFixed(1)}/5',
        caption: 'Overall front-to-back feel',
      ),
      (
        label: 'Avg experience',
        value: '${summary.averageComposite.toStringAsFixed(1)}/5',
        caption: 'Average across all six scores',
      ),
      (
        label: 'Follow-up ready',
        value: '${summary.contactOptIns}',
        caption: 'Guests who allowed contact',
      ),
      (
        label: 'Needs attention',
        value: '${summary.attentionNeeded}',
        caption: 'Low ratings or weak composite score',
      ),
      (
        label: 'Latest entry',
        value: summary.latestEntryAt == null
            ? 'Waiting'
            : _formatCompactDate(context, summary.latestEntryAt!),
        caption: summary.latestEntryAt == null
            ? 'No submissions yet'
            : _formatCompactTime(context, summary.latestEntryAt!),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wideLayout ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: wideLayout ? 1.9 : 1.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MetricCard(
          label: item.label,
          value: item.value,
          caption: item.caption,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(caption, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CategoryAveragesCard extends StatelessWidget {
  const _CategoryAveragesCard({required this.summary});

  final AdminFeedbackSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Category averages', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'These averages show where the visit is strongest and where table recovery may be needed.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: feedbackCategories.map((category) {
                final score = summary.categoryAverages[category.key] ?? 0;
                return _AveragePill(category: category, score: score);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AveragePill extends StatelessWidget {
  const _AveragePill({required this.category, required this.score});

  final FeedbackCategory category;
  final double score;

  @override
  Widget build(BuildContext context) {
    final option = feedbackOptionForValue(_normalizedScore(score));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: category.highlight.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            category.shortLabel,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            '${score.toStringAsFixed(1)}/5',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(option.label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.dense,
    required this.onOpen,
  });

  final AdminFeedbackSubmission submission;
  final bool dense;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = submission.comments.trim().isEmpty
        ? 'No additional notes left by the guest.'
        : submission.comments.trim();
    final metaText =
        '${submission.phone}  •  ${_formatDateTime(context, submission.createdAt)}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(dense ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          submission.name,
                          style: dense
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metaText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppPalette.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: dense ? 8 : 12),
                  _ScoreBadge(
                    score: submission.compositeScore,
                    label: submission.compositeLabel,
                    dense: dense,
                  ),
                ],
              ),
              SizedBox(height: dense ? 10 : 14),
              if (submission.contactConsent)
                Container(
                  margin: EdgeInsets.only(bottom: dense ? 10 : 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x332E7D5B),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Follow-up requested',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppPalette.success,
                    ),
                  ),
                ),
              Text(
                preview,
                maxLines: dense ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              SizedBox(height: dense ? 10 : 14),
              Wrap(
                spacing: dense ? 6 : 8,
                runSpacing: dense ? 6 : 8,
                children: feedbackCategories.map((category) {
                  final score = submission.ratings[category.key] ?? 0;
                  return _RatingTag(
                    category: category,
                    score: score,
                    dense: dense,
                  );
                }).toList(),
              ),
              if (!dense) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Tap to view full guest details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppPalette.emberDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingTag extends StatelessWidget {
  const _RatingTag({
    required this.category,
    required this.score,
    required this.dense,
  });

  final FeedbackCategory category;
  final int score;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Text(
        '${category.shortLabel} $score/5',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppPalette.ink),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.label,
    this.dense = false,
  });

  final double score;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final option = feedbackOptionForValue(_normalizedScore(score));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: _scoreColor(score).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(option.emoji, style: TextStyle(fontSize: dense ? 16 : 18)),
          const SizedBox(height: 2),
          Text(
            '${score.toStringAsFixed(1)}/5',
            style: dense
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            label,
            style: dense
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SubmissionDetailSheet extends StatelessWidget {
  const _SubmissionDetailSheet({required this.submission});

  final AdminFeedbackSubmission submission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppPalette.outline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(submission.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(submission.phone, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 6),
                  Text(
                    _formatDateTime(context, submission.createdAt),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ScoreBadge(
              score: submission.compositeScore,
              label: submission.compositeLabel,
            ),
          ],
        ),
        if (submission.contactConsent) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x332E7D5B),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Guest wants a follow-up call',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppPalette.success,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text('Ratings', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: feedbackCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (context, index) {
            final category = feedbackCategories[index];
            final score = submission.ratings[category.key] ?? 0;
            final option = feedbackOptionForValue(
              _normalizedScore(score.toDouble()),
            );

            return Card(
              color: category.highlight.withValues(alpha: 0.14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.shortLabel,
                      style: theme.textTheme.labelLarge,
                    ),
                    const Spacer(),
                    Text('$score/5', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(option.caption, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Comments', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              submission.comments.trim().isEmpty
                  ? 'No additional notes left by the guest.'
                  : submission.comments.trim(),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineAlert extends StatelessWidget {
  const _InlineAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1AB23A1F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33B23A1F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline_rounded, color: AppPalette.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

int _normalizedScore(double score) {
  if (score >= 4.5) return 5;
  if (score >= 3.5) return 4;
  if (score >= 2.5) return 3;
  if (score >= 1.5) return 2;
  return 1;
}

Color _scoreColor(double score) {
  if (score >= 4.5) return AppPalette.success;
  if (score >= 3.5) return AppPalette.ember;
  if (score >= 2.5) return AppPalette.amber;
  if (score >= 1.5) return const Color(0xFFD17C34);
  return AppPalette.danger;
}

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  final indiaTime = _toIndiaTime(value);
  final date = localizations.formatMediumDate(indiaTime);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(indiaTime));
  return '$date, $time IST';
}

String _formatCompactDate(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatShortDate(_toIndiaTime(value));
}

String _formatCompactTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(_toIndiaTime(value)),
  );
}

DateTime _toIndiaTime(DateTime value) {
  const indiaOffset = Duration(hours: 5, minutes: 30);
  if (value.isUtc) {
    return value.add(indiaOffset);
  }
  return value.toUtc().add(indiaOffset);
}
