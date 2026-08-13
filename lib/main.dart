import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_bootstrap.dart';
import 'config/app_features.dart';
import 'debug/flowdo_home_loop_diag.dart';
import 'debug/persist_device_verify.dart';
import 'debug/startup_trace.dart';
import 'debug/task_persistence_diag.dart';
import 'models/category_item.dart';
import 'models/task.dart';
import 'models/task_priority.dart';
import 'models/task_edit_result.dart';
import 'models/task_sort_mode.dart';
import 'models/task_repeat_type.dart';
import 'models/flowdo_calendar.dart';
import 'models/today_focus.dart';
import 'models/today_focus_completion_message.dart';
import 'models/completed_task_retention.dart';
import 'models/feedback_preferences.dart';
import 'models/flowdo_data_snapshot.dart';
import 'models/notification_preferences.dart';
import 'screens/settings_page.dart';
import 'screens/today_page.dart';
import 'services/app_storage.dart';
import 'services/auth/auth_service.dart';
import 'services/completed_task_cleanup.dart';
import 'services/data_protection/flowdo_backup_service.dart';
import 'services/data_protection/local_file_data_sync_adapter.dart';
import 'services/analytics/analytics_service.dart';
import 'services/crash_reporting.dart'
    show installStartupErrorHandlers, reportZonedError;
import 'services/feedback_service.dart';
import 'services/task_notification_service.dart';
import 'services/ai_categorizer_service.dart';
import 'services/task_organizer_service.dart';
import 'services/tasks/local_task_repository.dart';
import 'services/tasks/task_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'widgets/category_bar.dart';
import 'widgets/category_name_dialog.dart';
import 'widgets/calendar_day_task_sheet.dart';
import 'widgets/home_dashboard.dart';
import 'widgets/inbox_category_picker_sheet.dart';
import 'widgets/inbox_destination_selector.dart';
import 'widgets/inbox_group_preview_bar.dart';
import 'widgets/inbox_organization_progress.dart';
import 'widgets/flowdo_toast.dart';
import 'widgets/organize_tasks_button.dart';
import 'widgets/today_focus_task_sheet.dart';
import 'widgets/task_add_sheet.dart';
import 'widgets/task_due_datetime_sheet.dart';
import 'widgets/task_input_bar.dart';
import 'widgets/task_tile.dart';

Future<void> main() async {
  startupProbe(
    'build mode',
    kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
  );
  startupProbe('① main() entered');
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    startupProbe('② WidgetsFlutterBinding.ensureInitialized() done');
    if (await enterPersistVerifyOnlyMode()) {
      return;
    }
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
      startupProbe('③ bootstrapApp() starting');
      startupTrace('bootstrapApp() starting');
      final bootstrap = await bootstrapApp().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('App bootstrap timed out after 30 seconds'),
      );
      startupProbe('③ bootstrapApp() completed');
      startupTrace('bootstrapApp() completed');
      final taskNotificationService = createTaskNotificationService();
      startupProbe('④ runApp(FlowDoApp) calling');
      runApp(
        FlowDoApp(
          analyticsService: bootstrap.analyticsService,
          authService: bootstrap.authService,
          taskRepository: bootstrap.taskRepository,
          taskNotificationService: taskNotificationService,
        ),
      );
      startupProbe('④ runApp(FlowDoApp) called');
      startupTrace('runApp(FlowDoApp) called');
    } catch (error, stackTrace) {
      startupProbe('③ bootstrapApp() FAILED', error);
      startupTrace('bootstrapApp() FAILED', error);
      debugPrint('App bootstrap failed: $error');
      debugPrint(stackTrace.toString());
      startupProbe('④ runApp(BootstrapErrorApp) calling');
      runApp(BootstrapErrorApp(error: error));
      startupProbe('④ runApp(BootstrapErrorApp) called');
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
    this.taskNotificationService,
  });

  final AnalyticsService analyticsService;
  final AuthService authService;
  final TaskRepository taskRepository;
  final TaskNotificationService? taskNotificationService;

  @override
  State<FlowDoApp> createState() => _FlowDoAppState();
}

class _FlowDoAppState extends State<FlowDoApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  FeedbackPreferences _feedbackPreferences = FeedbackPreferences.defaults;
  NotificationPreferences _notificationPreferences =
      NotificationPreferences.defaults;
  CompletedTaskRetention _completedTaskRetention =
      CompletedTaskRetention.defaults;
  final FeedbackService _feedbackService = NativeFeedbackService();
  late final TaskNotificationService _taskNotificationService;
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    startupProbe('⑤ FlowDoApp.initState()');
    startupTrace('FlowDoApp.initState');
    _taskNotificationService =
        widget.taskNotificationService ?? createTaskNotificationService();
    WidgetsBinding.instance.addObserver(this);
    _sessionStartedAt = DateTime.now();
    unawaited(widget.analyticsService.logAppOpen());
    unawaited(
      runAfterFirstFrame(() async {
        startupTrace('FlowDoApp.runAfterFirstFrame callback start');
        if (await AppStorage.consumeFirstLaunchForAnalytics()) {
          unawaited(widget.analyticsService.logFirstLaunch());
        }
        unawaited(bootstrapAppStorage());
        unawaited(_restoreThemeMode());
        unawaited(_restoreFeedbackPreferences());
        unawaited(_bootstrapTaskNotifications());
        unawaited(_restoreCompletedTaskRetention());
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

  /// 通知基盤の lazy init + 設定復元 + 初回権限確認。
  /// bootstrapApp / タスク保存パスとは独立（post-frame のみ）。
  Future<void> _bootstrapTaskNotifications() async {
    if (!kTaskNotificationsEnabled) return;

    try {
      await safeInitializeTaskNotifications(_taskNotificationService);

      final preferences = await AppStorage.loadNotificationPreferences();
      _taskNotificationService.updatePreferences(preferences);
      if (mounted && preferences != _notificationPreferences) {
        setState(() => _notificationPreferences = preferences);
      }

      if (preferences.enabled &&
          await AppStorage.consumeNotificationPermissionPrompt()) {
        await _taskNotificationService.requestPermissions();
      }
    } catch (error, stack) {
      debugPrint('Task notification bootstrap failed: $error');
      debugPrint(stack.toString());
    }
  }

  Future<void> _setNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final previous = _notificationPreferences;
    if (preferences == previous) return;

    if (kTaskNotificationsEnabled &&
        preferences.enabled &&
        !previous.enabled) {
      try {
        await _taskNotificationService.initialize();
        await _taskNotificationService.requestPermissions();
      } catch (error, stack) {
        debugPrint('Notification permission request failed: $error');
        debugPrint(stack.toString());
      }
    }

    _taskNotificationService.updatePreferences(preferences);
    setState(() => _notificationPreferences = preferences);
    try {
      await AppStorage.saveNotificationPreferences(preferences);
    } catch (error, stack) {
      debugPrint('Failed to save notification preferences: $error');
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
    unawaited(_taskNotificationService.dispose());
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
    startupProbe('⑤ FlowDoApp.build()');
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
          taskNotificationService: _taskNotificationService,
          notificationPreferences: _notificationPreferences,
          onNotificationPreferencesChanged: _setNotificationPreferences,
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
    required this.taskNotificationService,
    required this.notificationPreferences,
    required this.onNotificationPreferencesChanged,
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
  final TaskNotificationService taskNotificationService;
  final NotificationPreferences notificationPreferences;
  final ValueChanged<NotificationPreferences> onNotificationPreferencesChanged;
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
  final ScrollController _scrollController = ScrollController();
  final PageController _homePageViewController = PageController();
  final GlobalKey _inputSectionKey = GlobalKey();
  final GlobalKey _inboxSectionAnchorKey = GlobalKey();
  final GlobalKey _categoryFilterAnchorKey = GlobalKey();
  final GlobalKey<TaskInputBarState> _taskInputBarKey = GlobalKey();
  bool _isLoading = true;
  bool _inputFocused = false;
  bool _showInputGuidance = false;
  bool _showInboxGuidance = false;
  bool _showFavoriteGuidance = false;
  final Set<String> _categoryFilterIds = {};
  final Set<String> _inboxSelectedCategoryIds = {};
  TaskSortMode _sortMode = TaskSortMode.priority;
  Timer? _layoutChangeTimer;
  TaskSortMode? _pendingLayoutSortMode;
  final Set<int> _deferredFilterTaskIds = {};
  final Set<int> _layoutHighlightTaskIds = {};
  final Set<int> _layoutAnimatingTaskIds = {};
  final Set<int> _registrationFeedbackTaskIds = {};
  final Map<int, bool> _pendingFavoriteByTaskId = {};
  static const _layoutChangeDelay = Duration(milliseconds: 2500);
  static const _dataSyncAdapter = LocalFileDataSyncAdapter();
  static const _layoutHighlightDelay = Duration(milliseconds: 400);
  static const _registrationFeedbackDuration = Duration(milliseconds: 500);
  static const _completionDelay = Duration(milliseconds: 2500);
  static const _completionAnimDuration = Duration(milliseconds: 250);
  static const _organizeAnimDuration = Duration(milliseconds: 250);
  static const _organizeStagger = Duration(milliseconds: 80);
  final Set<int> _completingTaskIds = {};
  final Set<int> _removingTaskIds = {};
  final Set<int> _organizingTaskIds = {};
  final Map<int, Timer> _completionTimers = {};
  final TaskOrganizerService _organizer = LocalTaskOrganizerService(
    categorizer: createAiCategorizerService(),
  );
  bool _isOrganizing = false;
  Timer? _keyboardScrollTimer;
  bool _isScrollingToInput = false;
  StreamSubscription<List<Task>>? _taskSubscription;
  bool _isApplyingRepositorySnapshot = false;
  bool _suppressRepositoryStreamHandling = false;
  Timer? _loadingFallbackTimer;
  late final ValueNotifier<int> _todayFocusSheetRevision;
  final TodayFocusCompletionMessages _todayFocusCompletionMessages =
      TodayFocusCompletionMessages();
  int? _pendingTodayFocusCelebrationTaskId;
  Set<int>? _inboxOrganizationCelebratedIds;

  @override
  void initState() {
    _todayFocusSheetRevision = ValueNotifier(0);
    super.initState();
    startupProbe('⑥ FlowDoHomePage.initState()');
    startupTrace('FlowDoHomePage.initState');
    FlowDoHomeLoopDiag.startIfNeeded();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.analyticsService.logScreenView(AnalyticsScreen.home));
    _bindTaskRepositoryStream();
    _loadingFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || !_isLoading) return;
      startupProbe('⑥ FlowDoHomePage loading timeout fallback');
      setState(() => _isLoading = false);
    });
    widget.taskNotificationService.onNotificationTap =
        _openTaskFromNotification;
    unawaited(
      runAfterFirstFrame(() async {
        startupTrace('FlowDoHomePage.runAfterFirstFrame callback start');
        await _loadMetadata();
        startupTrace('FlowDoHomePage._loadMetadata done');
        await _consumeNotificationLaunch();
      }),
    );
  }

  /// watchTasks() は initState で 1 回だけ bind する（didUpdateWidget で repository が
  /// 変わった場合のみ再 bind）。常に先に cancel してから listen し、同時に 1 本だけ保持する。
  void _bindTaskRepositoryStream() {
    _cancelTaskRepositoryStream();
    startupTrace('FlowDoHomePage.bind task stream subscription');
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
  }

  void _cancelTaskRepositoryStream() {
    final subscription = _taskSubscription;
    if (subscription == null) return;
    startupTrace('FlowDoHomePage.cancel task stream subscription');
    unawaited(subscription.cancel());
    _taskSubscription = null;
  }

  @override
  void didUpdateWidget(covariant FlowDoHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.taskRepository, widget.taskRepository)) {
      _bindTaskRepositoryStream();
    }
    if (oldWidget.completedTaskRetention != widget.completedTaskRetention) {
      unawaited(_purgeExpiredCompletedTasks());
    }
    if (oldWidget.notificationPreferences != widget.notificationPreferences) {
      widget.taskNotificationService.updatePreferences(
        widget.notificationPreferences,
      );
      if (kTaskNotificationsEnabled) {
        unawaited(widget.taskNotificationService.syncTasks(_tasks));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      final repository = widget.taskRepository;
      final repositoryMemoryCount =
          repository is LocalTaskRepository ? repository.memoryTaskCount : -1;
      logDiagBeforeAppExit(
        lifecycleState: state,
        repositoryMemoryTaskCount: repositoryMemoryCount,
        homePageTaskCount: _tasks.length,
      );
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_purgeExpiredCompletedTasks());
    }
  }

  void _openTaskFromNotification(int taskId) {
    if (!mounted) return;

    Task? task;
    for (final candidate in _tasks) {
      if (candidate.id == taskId) {
        task = candidate;
        break;
      }
    }
    if (task == null) return;

    unawaited(_showEditTaskSheet(task));
  }

  Future<void> _consumeNotificationLaunch() async {
    if (!kTaskNotificationsEnabled || !mounted) return;

    try {
      final taskId =
          await widget.taskNotificationService.readLaunchNotificationTaskId();
      if (taskId == null || !mounted) return;
      _openTaskFromNotification(taskId);
    } catch (error, stack) {
      debugPrint('Notification launch handling failed: $error');
      debugPrint(stack.toString());
    }
  }

  @override
  void dispose() {
    widget.taskNotificationService.onNotificationTap = null;
    startupProbe('⑥ FlowDoHomePage.dispose()');
    startupTrace('FlowDoHomePage.dispose');
    FlowDoHomeLoopDiag.stop();
    WidgetsBinding.instance.removeObserver(this);
    _loadingFallbackTimer?.cancel();
    _cancelTaskRepositoryStream();
    _keyboardScrollTimer?.cancel();
    _layoutChangeTimer?.cancel();
    _scrollController.dispose();
    _homePageViewController.dispose();
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    _inputController.dispose();
    _todayFocusSheetRevision.dispose();
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
    if (_completingTaskIds.contains(task.id)) return true;
    return DailyRoutineLogic.isCompletedToday(task, DateTime.now());
  }

  bool _isListedAsCompleted(Task task) {
    if (task.repeatType == TaskRepeatType.daily) return false;
    return task.isCompleted;
  }

  void _refreshTodayFocusSheet() {
    _todayFocusSheetRevision.value++;
  }

  Future<void> _showTodayFocusTaskSheet() async {
    _refreshTodayFocusSheet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: _todayFocusSheetRevision,
        builder: (context, _, __) => TodayFocusTaskSheet(
          sections: _todayFocusSections,
          onToggleTask: (taskId) async {
            final index = _tasks.indexWhere((task) => task.id == taskId);
            if (index < 0) return;
            final task = _tasks[index];
            if (!task.isCompleted && !_completingTaskIds.contains(task.id)) {
              unawaited(widget.feedbackService.playLightHaptic());
            }
            await _toggleTask(task, quietCompletionFeedback: true);
          },
          isRemoving: (taskId) => _removingTaskIds.contains(taskId),
          showCompletedStyle: (taskId) {
            final index = _tasks.indexWhere((task) => task.id == taskId);
            if (index < 0) return false;
            return _showsCompletedStyle(_tasks[index]);
          },
        ),
      ),
    );
  }

  Future<void> _showCalendarDaySheet(DateTime day, DateTime today) async {
    _refreshTodayFocusSheet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: _todayFocusSheetRevision,
        builder: (context, _, __) => CalendarDayTaskSheet(
          day: day,
          entries: calendarTasksForDay(
            tasks: _tasks,
            day: day,
            today: today,
            categories: _categories,
          ),
          onToggleTask: (taskId) async {
            final index = _tasks.indexWhere((task) => task.id == taskId);
            if (index < 0) return;
            final task = _tasks[index];
            if (!task.isCompleted && !_completingTaskIds.contains(task.id)) {
              unawaited(widget.feedbackService.playLightHaptic());
            }
            await _toggleTask(task, quietCompletionFeedback: true);
          },
          isRemoving: (taskId) => _removingTaskIds.contains(taskId),
          showCompletedStyle: (taskId) {
            final index = _tasks.indexWhere((task) => task.id == taskId);
            if (index < 0) return false;
            return _showsCompletedStyle(_tasks[index]);
          },
        ),
      ),
    );
  }

  bool _isRemovingTask(Task task) => _removingTaskIds.contains(task.id);

  bool _isLayoutHighlight(Task task) =>
      _layoutHighlightTaskIds.contains(task.id);

  bool _isRegistrationFeedback(Task task) =>
      _registrationFeedbackTaskIds.contains(task.id);

  bool _isLayoutAnimating(Task task) =>
      _layoutAnimatingTaskIds.contains(task.id);

  bool _isOrganizingTask(Task task) => _organizingTaskIds.contains(task.id);

  void _onOrganizeButtonPressed() {
    unawaited(_organizeInboxTasksManually());
  }

  Future<void> _organizeInboxTasksManually() async {
    final inboxTasks = _recentlyAddedTasks();
    if (inboxTasks.isEmpty) return;

    unawaited(_markInboxGuidanceSeenIfNeeded());

    await _updateTasks(() {
      for (final task in inboxTasks) {
        task.isInbox = false;
      }
      if (_sortMode != TaskSortMode.manual) {
        final sorted = sortTaskList(_tasks, _sortMode, _categories);
        _tasks
          ..clear()
          ..addAll(sorted);
      }
    });

    unawaited(
      widget.analyticsService.logCategoryChanged(
        context: AnalyticsContext.inbox,
      ),
    );
    unawaited(widget.feedbackService.play(FeedbackEvent.taskRegistered));

    if (!mounted) return;
    final count = inboxTasks.length;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$count件をタスクリストへ移動しました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scrollToCategoryFilter());
    });
  }


  Future<void> _scrollToInboxSection() => _scrollToAnchor(
        _inboxSectionAnchorKey,
        alignment: 0,
        extraScrollOffset: 12,
      );

  Future<void> _scrollToCategoryFilter() =>
      _scrollToAnchor(_categoryFilterAnchorKey, alignment: 0);

  Future<void> _scrollToAnchor(
    GlobalKey anchorKey, {
    double alignment = 0.08,
    double extraScrollOffset = 0,
  }) async {
    _taskInputBarKey.currentState?.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final targetContext = anchorKey.currentContext;
    if (targetContext == null || !_scrollController.hasClients) return;

    final renderObject = targetContext.findRenderObject();
    if (renderObject == null) return;

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport != null) {
      final targetOffset = (viewport
              .getOffsetToReveal(renderObject, alignment)
              .offset +
          extraScrollOffset)
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: alignment,
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
            content: Text('📌 をタップすると重要に設定できます'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      unawaited(AppStorage.markFavoriteGuidanceSeen());
    });
  }

  void _showImportantFeedback({required bool important}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            important ? '📌 重要に設定しました' : '📌 重要を解除しました',
          ),
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
    if (_pendingTodayFocusCelebrationTaskId == taskId) {
      _pendingTodayFocusCelebrationTaskId = null;
    }
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
    _refreshTodayFocusSheet();

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

    if (_pendingTodayFocusCelebrationTaskId == taskId) {
      _pendingTodayFocusCelebrationTaskId = null;
      _showTodayFocusCompletionMessage();
    }
  }

  void _showTodayFocusCompletionMessage() {
    if (!mounted) return;

    final message = _todayFocusCompletionMessages.pick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.text),
          duration: Duration(seconds: message.isRare ? 4 : 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    FlowDoHomeLoopDiag.onWatchEvent();
    if (_suppressRepositoryStreamHandling) return;
    startupTrace(
      'FlowDoHomePage.watchTasks snapshot',
      '${tasks.length} task(s)',
    );
    _applyTasksFromRepository(tasks);
  }

  bool _taskListsEquivalent(List<Task> current, List<Task> next) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.id != b.id ||
          a.title != b.title ||
          a.isCompleted != b.isCompleted ||
          a.isInbox != b.isInbox ||
          a.categoryId != b.categoryId ||
          a.isFavorite != b.isFavorite ||
          a.priorityStars != b.priorityStars ||
          a.dueDate != b.dueDate ||
          a.reminderTime != b.reminderTime ||
          a.completedAt != b.completedAt ||
          a.repeatType != b.repeatType) {
        return false;
      }
    }
    return true;
  }

  void _applyTasksFromRepository(List<Task> tasks) {
    FlowDoHomeLoopDiag.onApply();
    if (!mounted || _isApplyingRepositorySnapshot) return;
    _isApplyingRepositorySnapshot = true;
    try {
      startupTrace('_applyTasksFromRepository', '${tasks.length} task(s)');
      if (_isLoading) {
        startupTrace(
          'FlowDoHomePage initial task restore',
          '${tasks.length} task(s) from repository',
        );
      }

      CompletedTaskCleanup.backfillCompletionTimestamps(tasks);
      final resetChanged = DailyRoutineLogic.resetExpiredDailyTasks(tasks);
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

      logDiagBeforeUiApply(
        repositoryTaskCount: tasks.length,
        homePageTaskCountBefore: _tasks.length,
        retainedTaskCount: retainedTasks.length,
        homePageTaskCountAfter: updatedTasks.length,
        isInitialLoad: wasLoading,
      );

      if (!wasLoading && _taskListsEquivalent(_tasks, updatedTasks)) {
        return;
      }

      setState(() {
        _tasks
          ..clear()
          ..addAll(updatedTasks);
        _isLoading = false;
      });

      if (retainedTasks.length != tasks.length || resetChanged) {
        unawaited(_syncFilteredTasksToRepository(updatedTasks));
      }

      widget.taskNotificationService.updatePreferences(
        widget.notificationPreferences,
      );
      if (kTaskNotificationsEnabled) {
        unawaited(widget.taskNotificationService.syncTasks(_tasks));
      }

      if (wasLoading &&
          _showFavoriteGuidance &&
          !_showInboxGuidance &&
          _tasks.any((task) => !task.isInbox && !task.isCompleted)) {
        _maybeShowFavoriteGuidance();
      }
    } finally {
      _isApplyingRepositorySnapshot = false;
    }
  }

  Task _mergeTaskFromRemote({required Task remote, Task? existing}) {
    final taskId = remote.id;
    final favoriteUpdatePending = _isFavoriteUpdatePending(taskId);
    final pendingFavorite = _pendingFavoriteByTaskId[taskId];

    if (existing == null) {
      if (favoriteUpdatePending && pendingFavorite != null) {
        remote.isFavorite = pendingFavorite;
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
      ..reminderTime = remote.reminderTime
      ..completedAt = remote.completedAt
      ..repeatType = remote.repeatType;

    if (favoriteUpdatePending) {
      if (pendingFavorite != null && remote.isFavorite == pendingFavorite) {
        _pendingFavoriteByTaskId.remove(taskId);
        existing.isFavorite = remote.isFavorite;
      } else if (pendingFavorite != null) {
        existing.isFavorite = pendingFavorite;
      }
    } else {
      existing.isFavorite = remote.isFavorite;
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
    if (_tasks.every((task) => !_isListedAsCompleted(task))) return;

    await _updateTasks(() {
      _tasks.removeWhere((task) => _isListedAsCompleted(task));
    });
  }

  Future<void> _exportData() async {
    final snapshot = FlowDoBackupService.buildSnapshot(
      tasks: _tasks,
      categories: _categories,
      lastRegistrationCategoryId: _lastRegistrationCategoryId,
    );
    final json = FlowDoBackupService.encodeSnapshot(snapshot);
    final fileName = FlowDoBackupService.suggestedFileName(snapshot.exportedAt);

    try {
      await _dataSyncAdapter.shareExportJson(
        json: json,
        fileName: fileName,
      );
    } catch (error, stack) {
      debugPrint('Failed to export data: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      _showDataProtectionMessage('エクスポートに失敗しました');
    }
  }

  Future<void> _importData() async {
    final json = await _dataSyncAdapter.pickImportJson();
    if (json == null || !mounted) return;

    FlowDoDataSnapshot snapshot;
    try {
      snapshot = FlowDoBackupService.decodeSnapshot(json);
    } catch (error) {
      debugPrint('Invalid import JSON: $error');
      if (!mounted) return;
      _showDataProtectionMessage('バックアップファイルの形式が正しくありません');
      return;
    }

    final mode = await _showImportModeDialog(
      taskCount: snapshot.payload.tasks.length,
      categoryCount: snapshot.payload.categories.length,
    );
    if (mode == null || !mounted) return;

    final result = FlowDoBackupService.applyImport(
      snapshot: snapshot,
      currentTasks: _tasks,
      currentCategories: _categories,
      currentLastRegistrationCategoryId: _lastRegistrationCategoryId,
      mode: mode,
    );

    await _updateTasks(() {
      _tasks
        ..clear()
        ..addAll(result.tasks);
    });

    if (!mounted) return;

    setState(() {
      _categories = result.categories;
      _lastRegistrationCategoryId = result.lastRegistrationCategoryId;
    });
    await _saveCategories();
    if (result.lastRegistrationCategoryId != null) {
      await AppStorage.saveLastRegistrationCategoryId(
        result.lastRegistrationCategoryId!,
      );
    }

    if (!mounted) return;
    _showDataProtectionMessage(
      'インポート完了（タスク ${result.importedTaskCount} 件、'
      'カテゴリー ${result.importedCategoryCount} 件）',
    );
  }

  void _showDataProtectionMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<FlowDoImportMode?> _showImportModeDialog({
    required int taskCount,
    required int categoryCount,
  }) async {
    return showDialog<FlowDoImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSONをインポート'),
        content: Text(
          'タスク $taskCount 件、カテゴリー $categoryCount 件を読み込みます。\n'
          '既存データとの統合方法を選んでください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, FlowDoImportMode.merge),
            child: const Text('マージ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, FlowDoImportMode.replace),
            child: const Text('置き換え'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncFilteredTasksToRepository(List<Task> tasks) async {
    if (_isLoading) return;
    _suppressRepositoryStreamHandling = true;
    try {
      await widget.taskRepository.syncTasks(tasks);
    } catch (error, stack) {
      debugPrint('Failed to sync filtered tasks: $error');
      debugPrint(stack.toString());
    } finally {
      _suppressRepositoryStreamHandling = false;
    }
  }

  void _checkInboxOrganizationComplete() {
    final recentTasks = _recentlyAddedTasks();
    if (recentTasks.isEmpty) {
      _inboxOrganizationCelebratedIds = null;
      return;
    }

    final batchIds = recentTasks.map((task) => task.id).toSet();
    final organizedCount =
        recentTasks.where((task) => !task.isInboxUnorganized).length;
    if (organizedCount < recentTasks.length) {
      if (_inboxOrganizationCelebratedIds != null &&
          !_inboxOrganizationCelebratedIds!.containsAll(batchIds)) {
        _inboxOrganizationCelebratedIds = null;
      }
      return;
    }

    if (_inboxOrganizationCelebratedIds != null &&
        _inboxOrganizationCelebratedIds!.length == batchIds.length &&
        _inboxOrganizationCelebratedIds!.containsAll(batchIds)) {
      return;
    }

    _inboxOrganizationCelebratedIds = batchIds;
    FlowDoToast.show(context, '✨ 頭の中が整理できました。');
  }

  Future<void> _updateTasks(VoidCallback update) async {
    if (!mounted) return;
    setState(update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkInboxOrganizationComplete();
    });
    _refreshTodayFocusSheet();
    if (_isLoading) return;
    try {
      widget.taskNotificationService.updatePreferences(
        widget.notificationPreferences,
      );
      _suppressRepositoryStreamHandling = true;
      await widget.taskRepository.syncTasks(_tasks);
      if (kTaskNotificationsEnabled) {
        await widget.taskNotificationService.syncTasks(_tasks);
      }
    } catch (error, stack) {
      debugPrint('Failed to save tasks: $error');
      debugPrint(stack.toString());
    } finally {
      _suppressRepositoryStreamHandling = false;
    }
  }

  Future<void> _scheduleTaskNotificationIfNeeded(Task task) async {
    if (!kTaskNotificationsEnabled) return;

    try {
      widget.taskNotificationService.updatePreferences(
        widget.notificationPreferences,
      );

      if (!shouldScheduleTaskNotification(
        task,
        widget.notificationPreferences,
      )) {
        await widget.taskNotificationService.cancelTask(task.id);
        return;
      }

      if (!await widget.taskNotificationService.hasPermissions()) {
        await widget.taskNotificationService.requestPermissions();
      }

      await widget.taskNotificationService.scheduleTaskNotification(task);
    } catch (error, stack) {
      debugPrint('Task notification scheduling failed: $error');
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
    if (_inboxSelectedCategoryIds.length == 1) {
      return _inboxSelectedCategoryIds.first;
    }
    return CategoryItem.uncategorizedId;
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
    _inputController.clear();
    _taskInputBarKey.currentState?.unfocus();

    final registeredIds = <int>[];
    await _updateTasks(() {
      for (final title in titles) {
        final task = Task.create(title: title, categoryId: categoryId);
        registeredIds.add(task.id);
        _tasks.insert(0, task);
      }
    });
    if (categoryId != CategoryItem.uncategorizedId) {
      await _rememberLastRegistrationCategory(categoryId);
    }
    _inboxOrganizationCelebratedIds = null;

    if (registeredIds.isNotEmpty) {
      final count = registeredIds.length;
      FlowDoToast.show(context, '✅ $count件追加しました');

      _registrationFeedbackTaskIds.addAll(registeredIds);
      Future<void>.delayed(_registrationFeedbackDuration, () {
        if (!mounted) return;
        setState(() {
          _registrationFeedbackTaskIds.removeAll(registeredIds);
        });
      });
    }

    unawaited(_markInputGuidanceSeenIfNeeded());
    setState(() {});
    if (registeredIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_scrollToInboxSection());
        });
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
      return true;
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Task> _filteredTasks({required bool completed}) {
    final list = _tasks.where((task) {
      if (task.isInbox) return false;
      if (_isListedAsCompleted(task) != completed) return false;
      if (_categoryFilterIds.isNotEmpty &&
          !_categoryFilterIds.contains(task.categoryId) &&
          !_deferredFilterTaskIds.contains(task.id)) {
        return false;
      }
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
        list
            .where((task) => !_deferredFilterTaskIds.contains(task.id))
            .toList()
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

  int get _importantCount =>
      _tasks.where((t) => !t.isCompleted && t.isFavorite).length;
  int get _dueTodayCount =>
      _tasks.where((t) => !t.isCompleted && t.isDueToday).length;
  int get _dueWithin7DaysCount =>
      _tasks.where((t) => !t.isCompleted && t.isDueWithin7Days).length;

  List<TodayFocusSectionData> get _todayFocusSections {
    final important = _tasks
        .where((task) => !task.isCompleted && task.isFavorite)
        .toList()
      ..sort((a, b) {
        final priorityCompare = b.priorityStars.compareTo(a.priorityStars);
        if (priorityCompare != 0) return priorityCompare;
        return a.title.compareTo(b.title);
      });

    final dueToday = _tasks
        .where((task) => !task.isCompleted && task.isDueToday)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final dueWithin7Days = _tasks
        .where((task) => !task.isCompleted && task.isDueWithin7Days)
        .toList()
      ..sort((a, b) {
        final dueCompare = a.dueDate!.compareTo(b.dueDate!);
        if (dueCompare != 0) return dueCompare;
        return a.title.compareTo(b.title);
      });

    return [
      TodayFocusSectionData(
        kind: TodayFocusFilterKind.important,
        label: '重要',
        tasks: _todayFocusTaskItems(important),
      ),
      TodayFocusSectionData(
        kind: TodayFocusFilterKind.dueToday,
        label: '今日期限',
        tasks: _todayFocusTaskItems(dueToday),
      ),
      TodayFocusSectionData(
        kind: TodayFocusFilterKind.dueWithin7Days,
        label: '7日以内',
        tasks: _todayFocusTaskItems(dueWithin7Days),
      ),
    ];
  }

  List<TodayFocusTaskItem> _todayFocusTaskItems(List<Task> tasks) {
    return [
      for (final task in tasks)
        TodayFocusTaskItem(
          taskId: task.id,
          title: task.title,
          categoryName: resolveCategory(task.categoryId, _categories).name,
        ),
    ];
  }

  List<CategoryIncompleteCount> get _categoryIncompleteCounts {
    final counts = <String, int>{};
    for (final task in _tasks) {
      if (task.isCompleted) continue;
      counts.update(task.categoryId, (value) => value + 1, ifAbsent: () => 1);
    }

    final result = <CategoryIncompleteCount>[];
    for (final category in _categories) {
      final count = counts[category.id];
      if (count == null || count == 0) continue;
      result.add(CategoryIncompleteCount(category: category, count: count));
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  Future<void> _showEditTaskSheet(Task task) async {
    final result = await TaskEditSheet.show(
      context,
      title: task.title,
    );
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
    final categoryId = await InboxCategoryPickerSheet.showForTask(
      context,
      categories: _categories,
      selectedCategoryId: task.categoryId,
    );
    if (!mounted || categoryId == null || categoryId == task.categoryId) return;

    await _updateTasks(() {
      task.categoryId = categoryId;
    });
    unawaited(
      widget.analyticsService.logCategoryChanged(
        context: AnalyticsContext.inbox,
      ),
    );
    _showInboxCategorySetFeedback(
      resolveCategory(categoryId, _categories).name,
    );
    unawaited(_markInboxGuidanceSeenIfNeeded());
  }

  void _showInboxCategorySetFeedback(String categoryName) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$categoryNameに設定しました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showInboxDestinationPicker() async {
    final currentId = _inboxSelectedCategoryIds.length == 1
        ? _inboxSelectedCategoryIds.first
        : null;

    final pickedId = await InboxCategoryPickerSheet.showForDestination(
      context,
      categories: _categories,
      selectedCategoryId: currentId,
    );
    if (!mounted) return;

    if (pickedId == null) {
      if (currentId == null) return;
      setState(() => _inboxSelectedCategoryIds.clear());
      return;
    }

    // 最後に選択した操作が優先 — 同じ全体カテゴリーでも全タスクへ再適用
    await _onInboxCategoryBarSelected(pickedId);
  }

  Future<void> _onInboxCategoryBarSelected(String? categoryId) async {
    setState(() {
      _inboxSelectedCategoryIds.clear();
      if (categoryId != null) {
        _inboxSelectedCategoryIds.add(categoryId);
      }
    });

    if (categoryId == null) return;

    final categoryName = resolveCategory(categoryId, _categories).name;
    final inboxTasks =
        _tasks.where((task) => task.isInbox && !task.isCompleted).toList();

    if (inboxTasks.isEmpty) {
      await _rememberLastRegistrationCategory(categoryId);
      _showInboxCategorySetFeedback(categoryName);
      return;
    }

    await _updateTasks(() {
      for (final task in inboxTasks) {
        task.categoryId = categoryId;
      }
    });
    unawaited(
      widget.analyticsService.logCategoryChanged(
        context: AnalyticsContext.inbox,
      ),
    );
    await _rememberLastRegistrationCategory(categoryId);
    _showInboxCategorySetFeedback(categoryName);
    unawaited(_markInboxGuidanceSeenIfNeeded());
  }

  Future<void> _toggleImportant(Task task) async {
    if (!mounted) return;

    final index = _tasks.indexWhere((element) => element.id == task.id);
    if (index < 0) return;

    final target = _tasks[index];
    final important = !target.isFavorite;
    _pendingFavoriteByTaskId[target.id] = important;

    if (_showFavoriteGuidance) {
      _showFavoriteGuidance = false;
      unawaited(AppStorage.markFavoriteGuidanceSeen());
    }

    try {
      await _updateTasks(() {
        target.isFavorite = important;
      });

      if (mounted) {
        _showImportantFeedback(important: important);
      }
    } catch (error, stack) {
      debugPrint('Failed to update important: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      final revertIndex = _tasks.indexWhere((element) => element.id == task.id);
      if (revertIndex < 0) return;
      setState(() {
        _tasks[revertIndex].isFavorite = !important;
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
    if (task.isInbox) return;
    _scheduleDeferredLayout(taskId: task.id, sortMode: TaskSortMode.priority);
  }

  Future<void> _showTaskDueDateTimeSheet(
    Task task, {
    bool promptForTimeOnOpen = false,
  }) async {
    await TaskDueDateTimeSheet.show(
      context,
      initialDueDate: task.dueDate,
      initialReminderTime: task.reminderTime,
      initialRepeatType: task.repeatType,
      promptForTimeOnOpen: promptForTimeOnOpen,
      notificationPreferences: widget.notificationPreferences,
      notificationsFeatureEnabled: kTaskNotificationsEnabled,
      checkNotificationPermission: widget.taskNotificationService.hasPermissions,
      onRequestNotificationPermission:
          widget.taskNotificationService.requestPermissions,
      onDueDateChanged: (dueDate) => _applyDueDate(task, dueDate),
      onReminderTimeChanged: (reminderTime) =>
          _applyReminderTime(task, reminderTime),
      onRepeatTypeChanged: (repeatType) => _applyRepeatType(task, repeatType),
    );
  }

  Future<void> _pickDueDate(Task task) async {
    await _showTaskDueDateTimeSheet(task);
  }

  Future<void> _applyDueDate(Task task, DateTime? dueDate) async {
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _updateTasks(() {
      task.dueDate = dueDate;
      if (dueDate == null) {
        task.reminderTime = null;
      }
    });
    await _scheduleTaskNotificationIfNeeded(task);

    if (dueDate != null) {
      final daysUntilDue = dueDate.difference(today).inDays;
      unawaited(
        widget.analyticsService.logDeadlineSet(daysUntilDue: daysUntilDue),
      );
      if (task.isInbox) return;
      _scheduleDeferredLayout(
        taskId: task.id,
        sortMode: TaskSortMode.dueDate,
      );
    }
  }

  Future<void> _applyReminderTime(Task task, TimeOfDay? reminderTime) async {
    if (!mounted) return;
    await _updateTasks(() => task.reminderTime = reminderTime);
    await _scheduleTaskNotificationIfNeeded(task);
  }

  Future<void> _applyRepeatType(Task task, TaskRepeatType repeatType) async {
    if (!mounted) return;
    await _updateTasks(() => task.repeatType = repeatType);
    await _scheduleTaskNotificationIfNeeded(task);
  }

  Future<void> _deleteTask(Task task) async {
    _cancelCompletion(task.id);
    unawaited(widget.taskNotificationService.cancelTask(task.id));
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

  Future<void> _toggleTask(
    Task task, {
    bool quietCompletionFeedback = false,
  }) async {
    if (_completingTaskIds.contains(task.id)) {
      _cancelCompletion(task.id);
      setState(() {});
      return;
    }

    if (!DailyRoutineLogic.isCompletedToday(task, DateTime.now())) {
      unawaited(widget.taskNotificationService.cancelTask(task.id));
      final todayFocusEntries =
          flattenTodayFocusSections(_todayFocusSections);
      if (isLastRemainingTodayFocusTask(todayFocusEntries, task.id)) {
        _pendingTodayFocusCelebrationTaskId = task.id;
      }

      _completingTaskIds.add(task.id);
      _scheduleCompletion(task);
      if (!quietCompletionFeedback) {
        unawaited(widget.feedbackService.play(FeedbackEvent.taskCompleted));
      }
      setState(() {});
      _refreshTodayFocusSheet();
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
          notificationPreferences: widget.notificationPreferences,
          onNotificationPreferencesChanged:
              widget.onNotificationPreferencesChanged,
          completedTaskRetention: widget.completedTaskRetention,
          onCompletedTaskRetentionChanged:
              widget.onCompletedTaskRetentionChanged,
          onDeleteAllCompletedTasks: _deleteAllCompletedTasks,
          onExportData: _exportData,
          onImportData: _importData,
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
    FlowDoHomeLoopDiag.onBuild();
    startupProbe('⑥ FlowDoHomePage.build()', '_isLoading=$_isLoading');
    startupTrace('FlowDoHomePage.build', '_isLoading=$_isLoading');
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final recentTasks = _recentlyAddedTasks();
    final pendingTasks = _filteredTasks(completed: false);
    final completedTasks = _filteredTasks(completed: true);
    final hasFilter = _categoryFilterIds.isNotEmpty;
    final hasVisibleTasks =
        recentTasks.isNotEmpty ||
        pendingTasks.isNotEmpty ||
        completedTasks.isNotEmpty;
    final showNoResults =
        !_isLoading && _tasks.isNotEmpty && !hasVisibleTasks && hasFilter;
    final showStickyOrganizeCta = !_isLoading &&
        recentTasks.isNotEmpty &&
        !_isOrganizing;
    final inboxCount = recentTasks.length;
    final allInboxTasksCategorized = recentTasks.isNotEmpty &&
        recentTasks.every(
          (task) => task.categoryId != CategoryItem.uncategorizedId,
        );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : PageView(
                key: const ValueKey('flowdo_home_page_view'),
                controller: _homePageViewController,
                children: [
                  CustomScrollView(
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
                  if (!_isLoading)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KeyedSubtree(
                            key: _inboxSectionAnchorKey,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                              child: Text(
                                '整理待ちタスク'.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: colors.secondaryLabel,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ),
                          ),
                          if (_showInboxGuidance && recentTasks.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: InboxGuidanceBanner(),
                            ),
                          if (CategoryItem.filterBarCategories(_categories)
                              .isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                top: _showInboxGuidance && recentTasks.isNotEmpty
                                    ? 8
                                    : 12,
                              ),
                              child: InboxGroupPreviewBar(
                                key: const ValueKey('inbox_group_preview_bar'),
                                categories: _categories,
                                onAdd: _addCategory,
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              _showInboxGuidance && recentTasks.isNotEmpty
                                  ? 12
                                  : 16,
                              16,
                              7,
                            ),
                            child: Text(
                              'カテゴリー（全体）',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: 12.5,
                                    color: colors.secondaryLabel,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          InboxDestinationSelector(
                            categories: _categories,
                            selectedCategoryId:
                                _inboxSelectedCategoryIds.length == 1
                                    ? _inboxSelectedCategoryIds.first
                                    : null,
                            onTap: () => unawaited(_showInboxDestinationPicker()),
                          ),
                          recentTasks.isNotEmpty
                              ? GroupedTaskList(
                                  title: '整理待ちタスク',
                                  tasks: recentTasks,
                                  categories: _categories,
                                  showCompletedStyle: _showsCompletedStyle,
                                  isRemoving: _isOrganizingTask,
                                  isRegistrationFeedback:
                                      _isRegistrationFeedback,
                                  showCompletionToggle: false,
                                  openEditOnRowTap: false,
                                  onToggle: _toggleTask,
                                  onEdit: _showEditTaskSheet,
                                  onDelete: _confirmDeleteTask,
                                  onDismissDelete: _deleteTask,
                                  onCategoryTap: _showInboxCategoryPicker,
                                  onPriorityTap: _cyclePriority,
                                  onDueDateTap: _pickDueDate,
                                  onFavoriteTap: _toggleImportant,
                                  isInboxList: true,
                                  showSectionTitle: false,
                                )
                              : const SizedBox.shrink(),
                          if (recentTasks.isNotEmpty)
                            InboxOrganizationProgress(
                              organizedCount: recentTasks
                                  .where((task) => !task.isInboxUnorganized)
                                  .length,
                              totalCount: recentTasks.length,
                            ),
                          if (showStickyOrganizeCta)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: kAiOrganizeEnabled
                                  ? FilledButton(
                                      onPressed: _organizeRecentTasks,
                                      child: const Text('✨ AIで整理する'),
                                    )
                                  : OrganizeTasksButton(
                                      count: inboxCount,
                                      allCategoriesAssigned:
                                          allInboxTasksCategorized,
                                      onPressed: _onOrganizeButtonPressed,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: HomeDashboard(
                      tasks: _tasks,
                      onCalendarDayTap: _showCalendarDaySheet,
                      onOpenTodayFocusSheet: _showTodayFocusTaskSheet,
                      categoryCounts: _categoryIncompleteCounts,
                    ),
                  ),
                  if (!_isLoading)
                    SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: _categoryFilterAnchorKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 16, 7),
                              child: Text(
                                '表示するグループ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: 12.5,
                                    color: colors.secondaryLabel,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          CategoryBar(
                            key: const ValueKey('pending_category_filter_bar'),
                            categories: _categories,
                            selectedIds: _categoryFilterIds,
                            padding: const EdgeInsets.fromLTRB(
                              kCategoryBarHorizontalInset,
                              0,
                              kCategoryBarHorizontalInset,
                              0,
                            ),
                            addButtonKey:
                                const ValueKey('pending_category_add_chip'),
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
                        ],
                        ),
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
                          onFavoriteTap: _toggleImportant,
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
                          onFavoriteTap: _toggleImportant,
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
                  TodayPage(
                    key: const ValueKey('flowdo_today_page'),
                    embedded: true,
                    tasks: _tasks,
                    onRoutineToggle: (task) =>
                        unawaited(_toggleTask(task)),
                  ),
                ],
              ),
      ),
    );
  }
}
