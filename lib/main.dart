import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_bootstrap.dart';
import 'config/app_features.dart';
import 'debug/startup_trace.dart';
import 'models/category_item.dart';
import 'models/task.dart';
import 'models/task_priority.dart';
import 'models/task_edit_result.dart';
import 'models/task_sort_mode.dart';
import 'models/completed_task_retention.dart';
import 'models/feedback_preferences.dart';
import 'screens/settings_page.dart';
import 'services/app_storage.dart';
import 'services/auth/auth_service.dart';
import 'services/completed_task_cleanup.dart';
import 'services/analytics/analytics_service.dart';
import 'services/crash_reporting.dart'
    show installStartupErrorHandlers, reportZonedError;
import 'services/feedback_service.dart';
import 'services/ai_categorizer_service.dart';
import 'services/task_organizer_service.dart';
import 'services/tasks/task_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'widgets/category_bar.dart';
import 'widgets/category_name_dialog.dart';
import 'widgets/home_dashboard.dart';
import 'widgets/inbox_category_picker_sheet.dart';
import 'widgets/task_add_sheet.dart';
import 'widgets/task_input_bar.dart';
import 'widgets/task_tile.dart';

Future<void> main() async {
  startupTrace('main() entered');
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installStartupErrorHandlers();
    startupTrace('WidgetsFlutterBinding.ensureInitialized done');
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
      startupTrace('dotenv.load done');
    } catch (error, stackTrace) {
      debugPrint('.env load failed (OPENAI_API_KEY unavailable): $error');
      debugPrint(stackTrace.toString());
    }
    try {
      startupTrace('bootstrapApp() starting');
      final bootstrap = await bootstrapApp().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('App bootstrap timed out after 30 seconds'),
      );
      startupTrace('bootstrapApp() completed (auth restored, storage warmed)');
      runApp(
        FlowDoApp(
          analyticsService: bootstrap.analyticsService,
          authService: bootstrap.authService,
          taskRepository: bootstrap.taskRepository,
        ),
      );
      startupTrace('runApp(FlowDoApp) called');
    } catch (error, stackTrace) {
      startupTrace('bootstrapApp() FAILED', error);
      debugPrint('App bootstrap failed: $error');
      debugPrint(stackTrace.toString());
      runApp(BootstrapErrorApp(error: error));
      startupTrace('runApp(BootstrapErrorApp) called');
    }
  }, reportZonedError);
}

/// Firebase 初期化失敗時に白画面にならないようエラーを表示する
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FlowDo を起動できませんでした',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('$error'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FlowDoApp extends StatefulWidget {
  const FlowDoApp({
    super.key,
    required this.analyticsService,
    required this.authService,
    required this.taskRepository,
  });

  final AnalyticsService analyticsService;
  final AuthService authService;
  final TaskRepository taskRepository;

  @override
  State<FlowDoApp> createState() => _FlowDoAppState();
}

class _FlowDoAppState extends State<FlowDoApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  FeedbackPreferences _feedbackPreferences = FeedbackPreferences.defaults;
  CompletedTaskRetention _completedTaskRetention =
      CompletedTaskRetention.defaults;
  final FeedbackService _feedbackService = NativeFeedbackService();
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    startupTrace('FlowDoApp.initState');
    WidgetsBinding.instance.addObserver(this);
    _sessionStartedAt = DateTime.now();
    unawaited(widget.analyticsService.logAppOpen());
    unawaited(
      runAfterFirstFrame(() async {
        startupTrace('FlowDoApp.runAfterFirstFrame callback start');
        await bootstrapAppStorage();
        startupTrace('FlowDoApp.bootstrapAppStorage done');
        if (await AppStorage.consumeFirstLaunchForAnalytics()) {
          unawaited(widget.analyticsService.logFirstLaunch());
        }
        await Future.wait([
          _restoreThemeMode(),
          _restoreFeedbackPreferences(),
          _restoreCompletedTaskRetention(),
        ]);
        startupTrace('FlowDoApp.runAfterFirstFrame callback done');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _logSessionDuration();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartedAt = DateTime.now();
    }
  }

  void _logSessionDuration() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) return;

    final durationSeconds = DateTime.now().difference(startedAt).inSeconds;
    _sessionStartedAt = null;
    if (durationSeconds <= 0) return;

    unawaited(
      widget.analyticsService.logSessionDuration(
        durationSeconds: durationSeconds,
      ),
    );
  }

  Future<void> _restoreThemeMode() async {
    try {
      final mode = await AppStorage.loadThemeMode();
      if (!mounted || mode == _themeMode) return;
      setState(() => _themeMode = mode);
    } catch (error, stack) {
      debugPrint('Theme restore failed: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _restoreFeedbackPreferences() async {
    try {
      final preferences = await AppStorage.loadFeedbackPreferences();
      _feedbackService.updatePreferences(preferences);
      if (!mounted || preferences == _feedbackPreferences) return;
      setState(() => _feedbackPreferences = preferences);
    } catch (error, stack) {
      debugPrint('Feedback preferences restore failed: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _setFeedbackPreferences(FeedbackPreferences preferences) async {
    final previous = _feedbackPreferences;
    if (preferences == previous) return;

    if (preferences.soundEnabled != previous.soundEnabled) {
      unawaited(
        preferences.soundEnabled
            ? widget.analyticsService.logSoundEnabled()
            : widget.analyticsService.logSoundDisabled(),
      );
    }
    if (preferences.hapticEnabled != previous.hapticEnabled) {
      unawaited(
        preferences.hapticEnabled
            ? widget.analyticsService.logHapticEnabled()
            : widget.analyticsService.logHapticDisabled(),
      );
    }

    _feedbackService.updatePreferences(preferences);
    setState(() => _feedbackPreferences = preferences);
    try {
      await AppStorage.saveFeedbackPreferences(preferences);
    } catch (error, stack) {
      debugPrint('Failed to save feedback preferences: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _restoreCompletedTaskRetention() async {
    try {
      final retention = await AppStorage.loadCompletedTaskRetention();
      if (!mounted || retention == _completedTaskRetention) return;
      setState(() => _completedTaskRetention = retention);
    } catch (error, stack) {
      debugPrint('Completed task retention restore failed: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _setCompletedTaskRetention(
    CompletedTaskRetention retention,
  ) async {
    if (retention == _completedTaskRetention) return;
    setState(() => _completedTaskRetention = retention);
    try {
      await AppStorage.saveCompletedTaskRetention(retention);
    } catch (error, stack) {
      debugPrint('Failed to save completed task retention: $error');
      debugPrint(stack.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logSessionDuration();
    unawaited(_feedbackService.dispose());
    super.dispose();
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    setState(() => _themeMode = mode);
    unawaited(widget.analyticsService.logThemeChanged(mode));
    try {
      await AppStorage.saveThemeMode(mode);
    } catch (error, stack) {
      debugPrint('Failed to save theme mode: $error');
      debugPrint(stack.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    startupTrace('FlowDoApp.build');
    return MaterialApp(
      title: 'FlowDo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AuthGate(
        authService: widget.authService,
        signedInBuilder: (context) => FlowDoHomePage(
          key: const ValueKey('flowdo_home'),
          themeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
          feedbackService: _feedbackService,
          feedbackPreferences: _feedbackPreferences,
          onFeedbackPreferencesChanged: _setFeedbackPreferences,
          completedTaskRetention: _completedTaskRetention,
          onCompletedTaskRetentionChanged: _setCompletedTaskRetention,
          analyticsService: widget.analyticsService,
          authService: widget.authService,
          taskRepository: widget.taskRepository,
        ),
      ),
    );
  }
}

class FlowDoHomePage extends StatefulWidget {
  const FlowDoHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.feedbackService,
    required this.feedbackPreferences,
    required this.onFeedbackPreferencesChanged,
    required this.completedTaskRetention,
    required this.onCompletedTaskRetentionChanged,
    required this.analyticsService,
    required this.authService,
    required this.taskRepository,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final FeedbackService feedbackService;
  final FeedbackPreferences feedbackPreferences;
  final ValueChanged<FeedbackPreferences> onFeedbackPreferencesChanged;
  final CompletedTaskRetention completedTaskRetention;
  final ValueChanged<CompletedTaskRetention> onCompletedTaskRetentionChanged;
  final AnalyticsService analyticsService;
  final AuthService authService;
  final TaskRepository taskRepository;

  @override
  State<FlowDoHomePage> createState() => _FlowDoHomePageState();
}

class _FlowDoHomePageState extends State<FlowDoHomePage>
    with WidgetsBindingObserver {
  final List<Task> _tasks = [];
  List<CategoryItem> _categories = CategoryItem.defaults();
  String? _lastRegistrationCategoryId;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _inputSectionKey = GlobalKey();
  final GlobalKey _inboxSectionKey = GlobalKey();
  final GlobalKey<TaskInputBarState> _taskInputBarKey = GlobalKey();
  bool _isLoading = true;
  bool _inputFocused = false;
  bool _showInputGuidance = false;
  bool _showInboxGuidance = false;
  bool _showFavoriteGuidance = false;
  String _searchQuery = '';
  final Set<String> _categoryFilterIds = {};
  TaskSortMode _sortMode = TaskSortMode.priority;
  Timer? _layoutChangeTimer;
  TaskSortMode? _pendingLayoutSortMode;
  final Set<int> _deferredFilterTaskIds = {};
  final Set<int> _layoutHighlightTaskIds = {};
  final Set<int> _layoutAnimatingTaskIds = {};
  final Set<int> _registrationFeedbackTaskIds = {};
  final Map<int, bool> _pendingFavoriteByTaskId = {};
  static const _layoutChangeDelay = Duration(milliseconds: 2500);
  static const _inboxPromoteDelay = Duration(milliseconds: 2500);
  static const _layoutHighlightDelay = Duration(milliseconds: 400);
  static const _registrationFeedbackDuration = Duration(milliseconds: 500);
  static const _completionDelay = Duration(milliseconds: 2500);
  static const _completionAnimDuration = Duration(milliseconds: 250);
  static const _organizeAnimDuration = Duration(milliseconds: 250);
  static const _organizeStagger = Duration(milliseconds: 80);
  final Set<int> _completingTaskIds = {};
  final Set<int> _removingTaskIds = {};
  final Set<int> _organizingTaskIds = {};
  final Set<int> _inboxPromotePendingIds = {};
  final Map<int, Timer> _inboxPromoteTimers = {};
  final Map<int, Timer> _completionTimers = {};
  final TaskOrganizerService _organizer = LocalTaskOrganizerService(
    categorizer: createAiCategorizerService(),
  );
  bool _isOrganizing = false;
  Timer? _keyboardScrollTimer;
  bool _isScrollingToInput = false;
  StreamSubscription<List<Task>>? _taskSubscription;

  @override
  void initState() {
    super.initState();
    startupTrace('FlowDoHomePage.initState');
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.analyticsService.logScreenView(AnalyticsScreen.home));
    unawaited(
      runAfterFirstFrame(() async {
        startupTrace('FlowDoHomePage.runAfterFirstFrame callback start');
        await bootstrapAppStorage();
        startupTrace('FlowDoHomePage.bootstrapAppStorage done');
        startupTrace('FlowDoHomePage.watchTasks() subscribing');
        _taskSubscription = widget.taskRepository.watchTasks().listen(
          _onWatchTaskSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            startupTrace('FlowDoHomePage.watchTasks onError', error);
            debugPrint('Task stream failed: $error');
            debugPrint(stackTrace.toString());
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
        );
        startupTrace('FlowDoHomePage.watchTasks subscribed');
        await _loadMetadata();
        startupTrace('FlowDoHomePage._loadMetadata done');
      }),
    );
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void didUpdateWidget(covariant FlowDoHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completedTaskRetention != widget.completedTaskRetention) {
      unawaited(_purgeExpiredCompletedTasks());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_purgeExpiredCompletedTasks());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskSubscription?.cancel();
    _keyboardScrollTimer?.cancel();
    _layoutChangeTimer?.cancel();
    for (final timer in _inboxPromoteTimers.values) {
      timer.cancel();
    }
    _inboxPromoteTimers.clear();
    _scrollController.dispose();
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    _inputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_inputFocused) return;
    _keyboardScrollTimer?.cancel();
    _keyboardScrollTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_inputFocused) return;
      _scrollToInput();
    });
  }

  void _onInputFocusChanged(bool focused) {
    _inputFocused = focused;
    if (focused) {
      _scrollToInput();
    }
  }

  void _scrollToInput() {
    if (_isScrollingToInput) return;
    _isScrollingToInput = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScrollingToInput = false;
      if (!mounted) return;
      final context = _inputSectionKey.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _showsCompletedStyle(Task task) {
    return task.isCompleted || _completingTaskIds.contains(task.id);
  }

  bool _isRemovingTask(Task task) => _removingTaskIds.contains(task.id);

  bool _isLayoutHighlight(Task task) =>
      _layoutHighlightTaskIds.contains(task.id);

  bool _isRegistrationFeedback(Task task) =>
      _registrationFeedbackTaskIds.contains(task.id);

  bool _isLayoutAnimating(Task task) =>
      _layoutAnimatingTaskIds.contains(task.id);

  bool _isOrganizingTask(Task task) => _organizingTaskIds.contains(task.id);

  bool _isInboxPromotePending(Task task) =>
      _inboxPromotePendingIds.contains(task.id);

  void _cancelInboxPromote(int taskId) {
    _inboxPromoteTimers.remove(taskId)?.cancel();
    _inboxPromotePendingIds.remove(taskId);
  }

  Future<void> _scheduleInboxPromote(
    Task task, {
    String? categoryId,
  }) async {
    if (!task.isInbox) return;

    unawaited(_markInboxGuidanceSeenIfNeeded());

    if (categoryId != null && task.categoryId != categoryId) {
      await _updateTasks(() {
        task.categoryId = categoryId;
      });
      await _rememberLastRegistrationCategory(categoryId);
    }

    _cancelInboxPromote(task.id);
    _inboxPromotePendingIds.add(task.id);
    setState(() {});

    _inboxPromoteTimers[task.id] = Timer(_inboxPromoteDelay, () {
      if (!mounted) return;
      unawaited(_finalizeInboxPromote(task.id));
    });
  }

  Future<void> _finalizeInboxPromote(int taskId) async {
    _cancelInboxPromote(taskId);

    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;

    final task = _tasks[index];
    if (!task.isInbox) {
      if (mounted) setState(() {});
      return;
    }

    await _promoteInboxTask(task, categoryId: task.categoryId);
    if (mounted) setState(() {});
  }

  void _onOrganizeButtonPressed() {
    unawaited(_scrollToInboxSection(showFeedback: true));
  }

  Future<void> _scrollToInboxSection({bool showFeedback = false}) async {
    _taskInputBarKey.currentState?.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final targetContext = _inboxSectionKey.currentContext;
    if (targetContext != null && _scrollController.hasClients) {
      final renderObject = targetContext.findRenderObject();
      if (renderObject != null) {
        final viewport = RenderAbstractViewport.maybeOf(renderObject);
        if (viewport != null) {
          final targetOffset = viewport
              .getOffsetToReveal(renderObject, 0.06)
              .offset
              .clamp(
                _scrollController.position.minScrollExtent,
                _scrollController.position.maxScrollExtent,
              );
          await _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        } else {
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            alignment: 0.06,
          );
        }
      }
    }

    if (!mounted || !showFeedback) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('追加したタスクを整理しましょう'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _maybeShowFavoriteGuidance() {
    if (!_showFavoriteGuidance || _isLoading) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showFavoriteGuidance) return;
      _showFavoriteGuidance = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('📌 をタップするとタスクを最上位へ固定できます'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      unawaited(AppStorage.markFavoriteGuidanceSeen());
    });
  }

  void _showPinFeedback({required bool pinned}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pinned ? '最重要に固定しました' : '固定を解除しました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _markInputGuidanceSeenIfNeeded() async {
    if (!_showInputGuidance) return;
    if (!mounted) return;
    setState(() => _showInputGuidance = false);
    await AppStorage.markInputGuidanceSeen();
  }

  Future<void> _markInboxGuidanceSeenIfNeeded() async {
    if (!_showInboxGuidance) return;
    if (!mounted) return;
    setState(() => _showInboxGuidance = false);
    await AppStorage.markInboxGuidanceSeen();
  }

  void _cancelCompletion(int taskId) {
    _completionTimers.remove(taskId)?.cancel();
    _completingTaskIds.remove(taskId);
    _removingTaskIds.remove(taskId);
  }

  void _scheduleCompletion(Task task) {
    _completionTimers[task.id]?.cancel();
    _completionTimers[task.id] = Timer(_completionDelay, () {
      if (!mounted) return;
      _finalizeCompletion(task.id);
    });
  }

  Future<void> _finalizeCompletion(int taskId) async {
    _completionTimers.remove(taskId)?.cancel();
    if (!_completingTaskIds.contains(taskId)) return;

    _completingTaskIds.remove(taskId);
    _removingTaskIds.add(taskId);
    setState(() {});

    await Future<void>.delayed(_completionAnimDuration);
    if (!mounted) return;

    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) {
      _removingTaskIds.remove(taskId);
      return;
    }

    await _updateTasks(() {
      _tasks[index].isCompleted = true;
      _tasks[index].completedAt = DateTime.now();
      _removingTaskIds.remove(taskId);
    });
    unawaited(widget.analyticsService.logTaskCompleted());
  }

  void _scheduleDeferredLayout({
    required int taskId,
    required TaskSortMode sortMode,
  }) {
    _deferredFilterTaskIds.add(taskId);
    _pendingLayoutSortMode = sortMode;
    _layoutChangeTimer?.cancel();
    _layoutChangeTimer = Timer(_layoutChangeDelay, () {
      if (!mounted) return;
      unawaited(_finalizeDeferredLayout());
    });
  }

  Future<void> _finalizeDeferredLayout() async {
    _layoutChangeTimer?.cancel();
    _layoutChangeTimer = null;
    final sortMode = _pendingLayoutSortMode;
    _pendingLayoutSortMode = null;

    final tasksToAnimate = <int>{};
    if (_categoryFilterIds.isNotEmpty) {
      for (final taskId in _deferredFilterTaskIds) {
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index < 0) continue;

        if (!_categoryFilterIds.contains(_tasks[index].categoryId)) {
          tasksToAnimate.add(taskId);
        }
      }
    } else if (sortMode != null) {
      tasksToAnimate.addAll(_deferredFilterTaskIds);
    }

    if (tasksToAnimate.isNotEmpty) {
      _layoutHighlightTaskIds.addAll(tasksToAnimate);
      setState(() {});
      await Future<void>.delayed(_layoutHighlightDelay);
      if (!mounted) return;

      _layoutHighlightTaskIds.removeAll(tasksToAnimate);
      _layoutAnimatingTaskIds.addAll(tasksToAnimate);
      setState(() {});
      await Future<void>.delayed(_completionAnimDuration);
      if (!mounted) return;
      _layoutAnimatingTaskIds.removeAll(tasksToAnimate);
    }

    _deferredFilterTaskIds.clear();

    if (sortMode != null) {
      await _updateTasks(() {
        final sorted = sortTaskList(_tasks, sortMode, _categories);
        _tasks
          ..clear()
          ..addAll(sorted);
      });
    } else if (tasksToAnimate.isNotEmpty) {
      setState(() {});
    }
  }

  bool _isFavoriteUpdatePending(int taskId) =>
      _pendingFavoriteByTaskId.containsKey(taskId);

  void _onWatchTaskSnapshot(List<Task> tasks) {
    startupTrace(
      'FlowDoHomePage.watchTasks snapshot',
      '${tasks.length} task(s)',
    );
    _applyTasksFromRepository(tasks);
  }

  void _applyTasksFromRepository(List<Task> tasks) {
    startupTrace('_applyTasksFromRepository', '${tasks.length} task(s)');
    if (!mounted) return;

    CompletedTaskCleanup.backfillCompletionTimestamps(tasks);
    final retainedTasks = CompletedTaskCleanup.filterExpired(
      tasks,
      widget.completedTaskRetention,
    );

    final existingById = {for (final task in _tasks) task.id: task};
    final remoteIds = {for (final task in retainedTasks) task.id};
    final mergedById = {
      for (final remote in retainedTasks)
        remote.id: _mergeTaskFromRemote(
          remote: remote,
          existing: existingById[remote.id],
        ),
    };

    final wasLoading = _isLoading;
    final updatedTasks = <Task>[];

    if (wasLoading || _tasks.isEmpty) {
      updatedTasks.addAll([
        for (final remote in retainedTasks) mergedById[remote.id]!,
      ]);
    } else {
      final seen = <int>{};
      for (final task in _tasks) {
        final merged = mergedById[task.id];
        if (merged != null) {
          updatedTasks.add(merged);
          seen.add(task.id);
        } else if (!remoteIds.contains(task.id)) {
          updatedTasks.add(task);
          seen.add(task.id);
        }
      }
      for (final remote in retainedTasks) {
        if (!seen.contains(remote.id)) {
          updatedTasks.add(mergedById[remote.id]!);
        }
      }
    }

    setState(() {
      _tasks
        ..clear()
        ..addAll(updatedTasks);
      _isLoading = false;
    });

    if (retainedTasks.length != tasks.length) {
      unawaited(widget.taskRepository.syncTasks(_tasks));
    }

    if (wasLoading &&
        _showFavoriteGuidance &&
        !_showInboxGuidance &&
        _tasks.any((task) => !task.isInbox && !task.isCompleted)) {
      _maybeShowFavoriteGuidance();
    }
  }

  Task _mergeTaskFromRemote({required Task remote, Task? existing}) {
    final taskId = remote.id;
    final favoriteUpdatePending = _isFavoriteUpdatePending(taskId);
    final pendingFavorite = _pendingFavoriteByTaskId[taskId];

    if (existing == null) {
      if (favoriteUpdatePending && pendingFavorite != null) {
        remote.isFavorite = pendingFavorite;
        if (pendingFavorite) {
          remote.pinnedAt ??= DateTime.now();
        } else {
          remote.pinnedAt = null;
        }
      }
      return remote;
    }

    existing
      ..title = remote.title
      ..isCompleted = remote.isCompleted
      ..isInbox = remote.isInbox
      ..categoryId = remote.categoryId
      ..priorityStars = remote.priorityStars
      ..dueDate = remote.dueDate
      ..completedAt = remote.completedAt;

    // Firestore snapshot must not overwrite isFavorite while an update is pending.
    // Clear pending only after the remote document matches the intended value.
    if (favoriteUpdatePending) {
      if (pendingFavorite != null && remote.isFavorite == pendingFavorite) {
        _pendingFavoriteByTaskId.remove(taskId);
        existing.isFavorite = remote.isFavorite;
        existing.pinnedAt = remote.pinnedAt;
      } else if (pendingFavorite != null) {
        existing.isFavorite = pendingFavorite;
        if (pendingFavorite) {
          existing.pinnedAt ??= DateTime.now();
        } else {
          existing.pinnedAt = null;
        }
      }
    } else {
      existing.isFavorite = remote.isFavorite;
      existing.pinnedAt = remote.isFavorite ? remote.pinnedAt : null;
    }

    return existing;
  }

  Future<void> _loadMetadata() async {
    try {
      final results = await Future.wait([
        AppStorage.loadCategories(),
        AppStorage.loadLastRegistrationCategoryId(),
        AppStorage.shouldShowInputGuidance(),
        AppStorage.shouldShowInboxGuidance(),
        AppStorage.shouldShowFavoriteGuidance(),
      ]);
      if (!mounted) return;

      setState(() {
        _categories = results[0] as List<CategoryItem>;
        _lastRegistrationCategoryId = results[1] as String?;
        _showInputGuidance = results[2] as bool;
        _showInboxGuidance = results[3] as bool;
        _showFavoriteGuidance = results[4] as bool;
      });
    } catch (error, stack) {
      debugPrint('Failed to load app metadata: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() {
        _categories = CategoryItem.defaults();
      });
    }
  }

  Future<void> _purgeExpiredCompletedTasks() async {
    if (!mounted || _isLoading) return;

    CompletedTaskCleanup.backfillCompletionTimestamps(_tasks);
    final retainedTasks = CompletedTaskCleanup.filterExpired(
      _tasks,
      widget.completedTaskRetention,
    );
    if (retainedTasks.length == _tasks.length) return;

    await _updateTasks(() {
      _tasks
        ..clear()
        ..addAll(retainedTasks);
    });
  }

  Future<void> _deleteAllCompletedTasks() async {
    if (_tasks.every((task) => !task.isCompleted)) return;

    await _updateTasks(() {
      _tasks.removeWhere((task) => task.isCompleted);
    });
  }

  Future<void> _updateTasks(VoidCallback update) async {
    if (!mounted) return;
    setState(update);
    try {
      await widget.taskRepository.syncTasks(_tasks);
    } catch (error, stack) {
      debugPrint('Failed to save tasks: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _saveCategories() async {
    try {
      await AppStorage.saveCategories(_categories);
    } catch (error, stack) {
      debugPrint('Failed to save categories: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _addCategory(String name) async {
    if (!mounted) return;

    final colorIndex =
        _categories.where((c) => !c.isSystem).length %
        categoryColorPalette.length;
    final newCategory = CategoryItem.create(
      name: name,
      colorValue: categoryColorPalette[colorIndex],
    );

    setState(() {
      _categories = [..._categories, newCategory];
    });

    await _saveCategories();
  }

  Future<void> _renameCategory(CategoryItem category) async {
    if (!mounted) return;

    final newName = await showCategoryNameDialog(
      context,
      title: '名前変更',
      confirmLabel: '保存',
      initialName: category.name,
    );

    if (newName == null || newName.isEmpty || !mounted) return;

    await runAfterDialogClosed(() async {
      if (!mounted) return;

      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index < 0) return;

      setState(() {
        _categories = [
          for (final item in _categories)
            if (item.id == category.id) item.copyWith(name: newName) else item,
        ];
      });

      await _saveCategories();
    });
  }

  Future<void> _deleteCategory(CategoryItem category) async {
    if (category.isSystem) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カテゴリーを削除'),
        content: Text('「${category.name}」を削除しますか？\n関連タスクは未分類になります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await runAfterDialogClosed(() async {
      if (!mounted) return;

      setState(() {
        _categories = [
          for (final item in _categories)
            if (item.id != category.id) item,
        ];
        if (_categoryFilterIds.contains(category.id)) {
          _categoryFilterIds.remove(category.id);
        }
      });

      await _saveCategories();
      await _onCategoryDeleted(category.id);
    });
  }

  Future<void> _onCategoryDeleted(String deletedId) async {
    await _updateTasks(() {
      for (final task in _tasks) {
        if (task.categoryId == deletedId) {
          task.categoryId = CategoryItem.uncategorizedId;
        }
      }
    });
  }

  List<String> _extractTitles(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _registrationCategoryId() {
    return resolveRegistrationCategoryId(
      lastUsedId: _lastRegistrationCategoryId,
      categories: _categories,
    );
  }

  Future<void> _rememberLastRegistrationCategory(String categoryId) async {
    if (_lastRegistrationCategoryId == categoryId) return;
    _lastRegistrationCategoryId = categoryId;
    await AppStorage.saveLastRegistrationCategoryId(categoryId);
  }

  Future<void> _registerTasks() async {
    final titles = _extractTitles(_inputController.text);
    if (titles.isEmpty) return;

    final categoryId = _registrationCategoryId();
    final registeredIds = <int>[];
    await _updateTasks(() {
      for (final title in titles) {
        final task = Task.create(title: title, categoryId: categoryId);
        registeredIds.add(task.id);
        _tasks.insert(0, task);
      }
    });
    await _rememberLastRegistrationCategory(categoryId);

    if (registeredIds.isNotEmpty) {
      _registrationFeedbackTaskIds.addAll(registeredIds);
      Future<void>.delayed(_registrationFeedbackDuration, () {
        if (!mounted) return;
        setState(() {
          _registrationFeedbackTaskIds.removeAll(registeredIds);
        });
      });
    }

    _inputController.clear();
    _taskInputBarKey.currentState?.unfocus();
    unawaited(_markInputGuidanceSeenIfNeeded());
    setState(() {});
    if (_showInboxGuidance && registeredIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_scrollToInboxSection());
      });
    }
    unawaited(widget.feedbackService.play(FeedbackEvent.taskRegistered));
    final taskCount = registeredIds.length;
    unawaited(widget.analyticsService.logCaptureUsed(taskCount: taskCount));
    unawaited(widget.analyticsService.logTaskCreated(taskCount: taskCount));
    if (taskCount >= 2) {
      unawaited(widget.analyticsService.logBulkInputCount(count: taskCount));
    }
  }

  List<Task> _recentlyAddedTasks() {
    final list = _tasks.where((task) {
      if (!task.isInbox || task.isCompleted) return false;
      if (!task.matchesQuery(_searchQuery)) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      final pinnedCompare = comparePinnedOrder(a, b);
      if (pinnedCompare != 0) return pinnedCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<Task> _filteredTasks({required bool completed}) {
    final list = _tasks.where((task) {
      if (task.isInbox) return false;
      if (task.isCompleted != completed) return false;
      if (_categoryFilterIds.isNotEmpty &&
          !_categoryFilterIds.contains(task.categoryId) &&
          !_deferredFilterTaskIds.contains(task.id)) {
        return false;
      }
      if (!task.matchesQuery(_searchQuery)) return false;
      return true;
    }).toList();

    if (completed) {
      list.sort(compareCompletedTasks);
    } else if (_sortMode != TaskSortMode.manual) {
      return _sortPendingPreservingDeferred(list);
    }

    return list;
  }

  /// 2.5秒待機中のタスクは現在位置を維持し、それ以外だけ並び替える
  List<Task> _sortPendingPreservingDeferred(List<Task> list) {
    if (_deferredFilterTaskIds.isEmpty) {
      list.sort((a, b) => compareTasksBySortMode(a, b, _sortMode, _categories));
      return list;
    }

    final sortedOthers =
        list.where((task) => !_deferredFilterTaskIds.contains(task.id)).toList()
          ..sort(
            (a, b) => compareTasksBySortMode(a, b, _sortMode, _categories),
          );

    var otherIndex = 0;
    return [
      for (final task in list)
        if (_deferredFilterTaskIds.contains(task.id))
          task
        else
          sortedOthers[otherIndex++],
    ];
  }

  Future<void> _applySort(TaskSortMode mode) async {
    _layoutChangeTimer?.cancel();
    _pendingLayoutSortMode = null;
    _deferredFilterTaskIds.clear();
    _layoutHighlightTaskIds.clear();
    _layoutAnimatingTaskIds.clear();
    setState(() => _sortMode = mode);

    if (mode == TaskSortMode.manual) return;

    await _updateTasks(() {
      final sorted = sortTaskList(_tasks, mode, _categories);
      _tasks
        ..clear()
        ..addAll(sorted);
    });
  }

  Future<void> _organizeRecentTasks() async {
    if (_isOrganizing) return;

    final recentTasks = _recentlyAddedTasks();
    if (recentTasks.isEmpty) return;

    _isOrganizing = true;
    setState(() {});
    unawaited(
      widget.analyticsService.logAiSortStarted(taskCount: recentTasks.length),
    );

    await widget.feedbackService.runOrganizeFeedback(() async {
      final plans = await _organizer.planOrganization(
        inboxTasks: recentTasks,
        categories: _categories,
      );

      for (final plan in plans) {
        if (!mounted) return;
        _organizingTaskIds.add(plan.taskId);
        setState(() {});
        await Future<void>.delayed(_organizeStagger);
      }

      await Future<void>.delayed(_organizeAnimDuration);
      if (!mounted) return;

      await _updateTasks(() {
        for (final plan in plans) {
          final index = _tasks.indexWhere((t) => t.id == plan.taskId);
          if (index < 0) continue;
          // 整理はカテゴリー振り分けと一覧への移動のみ（優先度・期限は変更しない）
          _tasks[index].categoryId = plan.categoryId;
          _tasks[index].isInbox = false;
          _organizingTaskIds.remove(plan.taskId);
        }
      });

      if (mounted) setState(() {});
    });

    _isOrganizing = false;
    if (mounted) setState(() {});
    unawaited(
      widget.analyticsService.logAiSortCompleted(taskCount: recentTasks.length),
    );
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<TaskSortMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '並び替え',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final mode in TaskSortMode.values)
              ListTile(
                leading: Icon(
                  _sortMode == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(mode.label),
                onTap: () => Navigator.pop(context, mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _applySort(selected);
  }

  int get _pendingCount => _tasks.where((t) => !t.isCompleted).length;
  int get _completedCount => _tasks.where((t) => t.isCompleted).length;
  int get _dueTodayCount => _tasks.where((t) => t.isDueToday).length;

  Future<void> _showEditTaskSheet(Task task) async {
    final result = await TaskEditSheet.show(context, title: task.title);
    if (!mounted || result == null) return;

    switch (result) {
      case TaskEditDeleted():
        await _deleteTask(task);
      case TaskEditSaved(:final title):
        if (title == task.title) return;
        await _updateTasks(() {
          task.title = title;
        });
    }
  }

  String _taskAnalyticsContext(Task task) {
    return task.isInbox ? AnalyticsContext.inbox : AnalyticsContext.list;
  }

  Future<void> _cycleCategory(Task task) async {
    await _updateTasks(() {
      task.categoryId = nextCategoryId(task.categoryId, _categories);
    });
    unawaited(
      widget.analyticsService.logCategoryChanged(
        context: _taskAnalyticsContext(task),
      ),
    );
    await _rememberLastRegistrationCategory(task.categoryId);
    if (task.isInbox) return;
    _scheduleDeferredLayout(taskId: task.id, sortMode: TaskSortMode.category);
  }

  Future<void> _showInboxCategoryPicker(Task task) async {
    final categoryId = await InboxCategoryPickerSheet.show(
      context,
      categories: _categories,
      selectedCategoryId: task.categoryId,
    );
    if (!mounted || categoryId == null) return;
    await _scheduleInboxPromote(task, categoryId: categoryId);
  }

  Future<void> _promoteInboxTask(
    Task task, {
    required String categoryId,
  }) async {
    if (!task.isInbox) return;

    final categoryName = resolveCategory(categoryId, _categories).name;

    await _updateTasks(() {
      task.categoryId = categoryId;
      task.isInbox = false;
    });
    unawaited(
      widget.analyticsService.logCategoryChanged(
        context: AnalyticsContext.inbox,
      ),
    );
    await _rememberLastRegistrationCategory(categoryId);
    _showInboxMoveFeedback(categoryName);
    unawaited(widget.feedbackService.play(FeedbackEvent.taskRegistered));

    if (_sortMode != TaskSortMode.manual) {
      _scheduleDeferredLayout(
        taskId: task.id,
        sortMode: TaskSortMode.category,
      );
    }
  }

  void _showInboxMoveFeedback(String categoryName) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$categoryNameへ移動しました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _promoteInboxTaskWithCurrentCategory(Task task) async {
    await _scheduleInboxPromote(task);
  }

  Future<void> _togglePin(Task task) async {
    if (!mounted) return;

    final index = _tasks.indexWhere((element) => element.id == task.id);
    if (index < 0) return;

    final target = _tasks[index];
    final pinned = !target.isFavorite;
    final previousPinnedAt = target.pinnedAt;
    _pendingFavoriteByTaskId[target.id] = pinned;

    if (_showFavoriteGuidance) {
      _showFavoriteGuidance = false;
      unawaited(AppStorage.markFavoriteGuidanceSeen());
    }

    try {
      await _updateTasks(() {
        target.isFavorite = pinned;
        target.pinnedAt = pinned ? DateTime.now() : null;
        _tasks.removeAt(index);
        _tasks.insert(
          pinReorderIndex(
            tasks: _tasks,
            task: target,
            sortMode: _sortMode,
            categories: _categories,
          ),
          target,
        );
      });
      if (mounted) _showPinFeedback(pinned: pinned);
    } catch (error, stack) {
      debugPrint('Failed to update pin: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      final revertIndex = _tasks.indexWhere((element) => element.id == task.id);
      if (revertIndex < 0) return;
      setState(() {
        _tasks[revertIndex].isFavorite = !pinned;
        _tasks[revertIndex].pinnedAt = previousPinnedAt;
      });
      _pendingFavoriteByTaskId.remove(target.id);
    }
  }

  Future<void> _cyclePriority(Task task) async {
    await _updateTasks(() {
      task.priorityStars = TaskPriorityStars.next(task.priorityStars);
    });
    unawaited(
      widget.analyticsService.logPriorityChanged(
        context: _taskAnalyticsContext(task),
        stars: task.priorityStars,
      ),
    );
    if (task.isInbox) {
      await _scheduleInboxPromote(task);
      return;
    }
    _scheduleDeferredLayout(taskId: task.id, sortMode: TaskSortMode.priority);
  }

  Future<void> _pickDueDate(Task task) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (!mounted) return;

    if (picked != null) {
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(picked.year, picked.month, picked.day);
      final daysUntilDue = due.difference(today).inDays;
      await _updateTasks(() => task.dueDate = picked);
      unawaited(
        widget.analyticsService.logDeadlineSet(daysUntilDue: daysUntilDue),
      );
      if (task.isInbox) {
        await _scheduleInboxPromote(task);
      } else {
        _scheduleDeferredLayout(
          taskId: task.id,
          sortMode: TaskSortMode.dueDate,
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    _cancelCompletion(task.id);
    _cancelInboxPromote(task.id);
    await _updateTasks(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    unawaited(widget.analyticsService.logTaskDeleted());
  }

  Future<void> _confirmDeleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクを削除'),
        content: Text('「${task.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) await _deleteTask(task);
  }

  Future<void> _toggleTask(Task task) async {
    if (_completingTaskIds.contains(task.id)) {
      _cancelCompletion(task.id);
      setState(() {});
      return;
    }

    if (!task.isCompleted) {
      _completingTaskIds.add(task.id);
      _scheduleCompletion(task);
      unawaited(widget.feedbackService.play(FeedbackEvent.taskCompleted));
      setState(() {});
      return;
    }

    await _updateTasks(() {
      task.isCompleted = false;
      task.completedAt = null;
    });
  }

  void _openSettings() {
    unawaited(widget.analyticsService.logScreenView(AnalyticsScreen.settings));
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          feedbackPreferences: widget.feedbackPreferences,
          onFeedbackPreferencesChanged: widget.onFeedbackPreferencesChanged,
          completedTaskRetention: widget.completedTaskRetention,
          onCompletedTaskRetentionChanged:
              widget.onCompletedTaskRetentionChanged,
          onDeleteAllCompletedTasks: _deleteAllCompletedTasks,
          authService: widget.authService,
          onSignInWithGoogle: () => _signInWithGuestMigration(
            widget.authService.signInWithGoogle,
          ),
          onSignInWithApple: () => _signInWithGuestMigration(
            widget.authService.signInWithApple,
          ),
          onSignOut: widget.authService.signOut,
        ),
      ),
    );
  }

  Future<void> _signInWithGuestMigration(
    Future<void> Function() signIn,
  ) async {
    final repository = widget.taskRepository;
    if (repository is AuthAwareTaskRepository) {
      repository.prepareGuestDataMigration();
    }
    await signIn();
  }

  @override
  Widget build(BuildContext context) {
    startupTrace('FlowDoHomePage.build', '_isLoading=$_isLoading');
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final recentTasks = _recentlyAddedTasks();
    final pendingTasks = _filteredTasks(completed: false);
    final completedTasks = _filteredTasks(completed: true);
    final hasFilter = _searchQuery.isNotEmpty || _categoryFilterIds.isNotEmpty;
    final hasVisibleTasks =
        recentTasks.isNotEmpty ||
        pendingTasks.isNotEmpty ||
        completedTasks.isNotEmpty;
    final showNoResults =
        !_isLoading && _tasks.isNotEmpty && !hasVisibleTasks && hasFilter;
    final showOrganizeButton = kAiOrganizeEnabled &&
        !_isLoading &&
        !_isOrganizing &&
        recentTasks.isNotEmpty;
    final showManualOrganizeBar = !kAiOrganizeEnabled &&
        !_isLoading &&
        recentTasks.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: showOrganizeButton
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(
                onPressed: _isOrganizing ? null : _organizeRecentTasks,
                child: const Text('✨ AIで整理する'),
              ),
            )
          : showManualOrganizeBar
              ? SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: FilledButton.tonal(
                    onPressed: _onOrganizeButtonPressed,
                    child: const Text('整理する'),
                  ),
                )
              : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    backgroundColor: colors.groupedBackground,
                    surfaceTintColor: Colors.transparent,
                    title: const Text('FlowDo'),
                    actions: [
                      TextButton(
                        onPressed: _showSortMenu,
                        child: const Text('並び替え'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: '設定',
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    key: _inputSectionKey,
                    child: TaskInputBar(
                      key: _taskInputBarKey,
                      controller: _inputController,
                      onSubmit: _registerTasks,
                      onFocusChanged: _onInputFocusChanged,
                      showGuidance: _showInputGuidance,
                    ),
                  ),
                  if (recentTasks.isNotEmpty)
                    SliverToBoxAdapter(
                      key: _inboxSectionKey,
                      child: GroupedTaskList(
                        title: '追加したタスク',
                        tasks: recentTasks,
                        categories: _categories,
                        showCompletedStyle: _showsCompletedStyle,
                        isRemoving: _isOrganizingTask,
                        isRegistrationFeedback: _isRegistrationFeedback,
                        isInboxPromotePending: _isInboxPromotePending,
                        showCompletionToggle: false,
                        openEditOnRowTap: true,
                        onToggle: _toggleTask,
                        onEdit: _showEditTaskSheet,
                        onDelete: _confirmDeleteTask,
                        onDismissDelete: _deleteTask,
                        onCategoryTap: _showInboxCategoryPicker,
                        onPriorityTap: _cyclePriority,
                        onDueDateTap: _pickDueDate,
                        onFavoriteTap: _togglePin,
                        isInboxList: true,
                        showInboxGuidance: _showInboxGuidance,
                        onPromoteTask: _promoteInboxTaskWithCurrentCategory,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: HomeDashboard(
                      completedCount: _completedCount,
                      pendingCount: _pendingCount,
                      dueTodayCount: _dueTodayCount,
                      totalCount: _tasks.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        key: const ValueKey('task_search_field'),
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'タスクを検索',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _searchController.clear,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CategoryBar(
                      categories: _categories,
                      selectedIds: _categoryFilterIds,
                      onSelected: (id) {
                        setState(() {
                          if (id == null) {
                            _categoryFilterIds.clear();
                          } else if (_categoryFilterIds.contains(id)) {
                            _categoryFilterIds.remove(id);
                          } else {
                            _categoryFilterIds.add(id);
                          }
                        });
                      },
                      onAdd: _addCategory,
                      onRename: _renameCategory,
                      onDelete: _deleteCategory,
                    ),
                  ),
                  if (_tasks.isEmpty && !hasFilter)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            '上の入力欄にタスクを入力して登録してください',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.secondaryLabel),
                          ),
                        ),
                      ),
                    )
                  else if (showNoResults)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          '該当するタスクがありません',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.secondaryLabel),
                        ),
                      ),
                    )
                  else ...[
                    if (pendingTasks.isNotEmpty)
                      SliverToBoxAdapter(
                        child: GroupedTaskList(
                          title: '未完了',
                          tasks: pendingTasks,
                          categories: _categories,
                          showCompletedStyle: _showsCompletedStyle,
                          isLayoutHighlight: _isLayoutHighlight,
                          isLayoutAnimating: _isLayoutAnimating,
                          isRemoving: _isRemovingTask,
                          onToggle: _toggleTask,
                          onEdit: _showEditTaskSheet,
                          onDelete: _confirmDeleteTask,
                          onDismissDelete: _deleteTask,
                          onCategoryTap: _cycleCategory,
                          onPriorityTap: _cyclePriority,
                          onDueDateTap: _pickDueDate,
                          onFavoriteTap: _togglePin,
                        ),
                      ),
                    if (completedTasks.isNotEmpty)
                      SliverToBoxAdapter(
                        child: GroupedTaskList(
                          title: '完了',
                          tasks: completedTasks,
                          categories: _categories,
                          isCompletedList: true,
                          showCompletedStyle: _showsCompletedStyle,
                          isLayoutHighlight: _isLayoutHighlight,
                          isLayoutAnimating: _isLayoutAnimating,
                          isRemoving: _isRemovingTask,
                          onToggle: _toggleTask,
                          onEdit: _showEditTaskSheet,
                          onDelete: _confirmDeleteTask,
                          onDismissDelete: _deleteTask,
                          onCategoryTap: _cycleCategory,
                          onPriorityTap: _cyclePriority,
                          onDueDateTap: _pickDueDate,
                          onFavoriteTap: _togglePin,
                        ),
                      ),
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(height: showOrganizeButton ? 8 : 24),
                  ),
                ],
              ),
      ),
    );
  }
}
