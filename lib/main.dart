import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_bootstrap.dart';
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
import 'services/crash_reporting.dart' show reportZonedError;
import 'services/feedback_service.dart';
import 'services/task_organizer_service.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'widgets/category_bar.dart';
import 'widgets/category_name_dialog.dart';
import 'widgets/home_dashboard.dart';
import 'widgets/task_add_sheet.dart';
import 'widgets/task_input_bar.dart';
import 'widgets/task_tile.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final bootstrap = await bootstrapApp();
      runApp(
        FlowDoApp(
          analyticsService: bootstrap.analyticsService,
          authService: bootstrap.authService,
        ),
      );
    },
    reportZonedError,
  );
}

class FlowDoApp extends StatefulWidget {
  const FlowDoApp({
    super.key,
    required this.analyticsService,
    required this.authService,
  });

  final AnalyticsService analyticsService;
  final AuthService authService;

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
    WidgetsBinding.instance.addObserver(this);
    _sessionStartedAt = DateTime.now();
    unawaited(widget.analyticsService.logAppOpen());
    unawaited(
      runAfterFirstFrame(() async {
        await bootstrapAppStorage();
        if (await AppStorage.consumeFirstLaunchForAnalytics()) {
          unawaited(widget.analyticsService.logFirstLaunch());
        }
        await Future.wait([
          _restoreThemeMode(),
          _restoreFeedbackPreferences(),
          _restoreCompletedTaskRetention(),
        ]);
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
  bool _isLoading = true;
  bool _inputFocused = false;
  String _searchQuery = '';
  String? _categoryFilterId;
  TaskSortMode _sortMode = TaskSortMode.priority;
  Timer? _layoutChangeTimer;
  TaskSortMode? _pendingLayoutSortMode;
  final Set<int> _deferredFilterTaskIds = {};
  final Set<int> _layoutHighlightTaskIds = {};
  final Set<int> _layoutAnimatingTaskIds = {};
  final Set<int> _registrationFeedbackTaskIds = {};
  static const _layoutChangeDelay = Duration(milliseconds: 2500);
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
  final TaskOrganizerService _organizer = const LocalTaskOrganizerService();
  bool _isOrganizing = false;
  Timer? _keyboardScrollTimer;
  bool _isScrollingToInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.analyticsService.logScreenView(AnalyticsScreen.home));
    unawaited(
      runAfterFirstFrame(() async {
        await bootstrapAppStorage();
        await _loadData();
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
    _keyboardScrollTimer?.cancel();
    _layoutChangeTimer?.cancel();
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
    if (_categoryFilterId != null) {
      for (final taskId in _deferredFilterTaskIds) {
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index < 0) continue;
        if (_tasks[index].categoryId != _categoryFilterId) {
          tasksToAnimate.add(taskId);
        }
      }
    } else if (sortMode != null && sortMode != TaskSortMode.manual) {
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

    if (sortMode != null && sortMode != TaskSortMode.manual) {
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

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        AppStorage.loadTasks(),
        AppStorage.loadCategories(),
        AppStorage.loadLastRegistrationCategoryId(),
      ]);
      if (!mounted) return;

      final tasks = results[0] as List<Task>;
      CompletedTaskCleanup.backfillCompletionTimestamps(tasks);
      final retainedTasks = CompletedTaskCleanup.filterExpired(
        tasks,
        widget.completedTaskRetention,
      );

      setState(() {
        _tasks
          ..clear()
          ..addAll(retainedTasks);
        _categories = results[1] as List<CategoryItem>;
        _lastRegistrationCategoryId = results[2] as String?;
        _isLoading = false;
      });

      if (retainedTasks.length != tasks.length) {
        await AppStorage.saveTasks(_tasks);
      }
    } catch (error, stack) {
      debugPrint('Failed to load app data: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() {
        _tasks.clear();
        _categories = CategoryItem.defaults();
        _isLoading = false;
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
      await AppStorage.saveTasks(_tasks);
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
        _categories.where((c) => !c.isSystem).length % categoryColorPalette.length;
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
        if (_categoryFilterId == category.id) {
          _categoryFilterId = null;
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
    setState(() {});
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

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Task> _filteredTasks({required bool completed}) {
    final list = _tasks.where((task) {
      if (task.isInbox) return false;
      if (task.isCompleted != completed) return false;
      if (_categoryFilterId != null &&
          task.categoryId != _categoryFilterId &&
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
      list.sort(
        (a, b) => compareTasksBySortMode(a, b, _sortMode, _categories),
      );
      return list;
    }

    final sortedOthers = list
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
    _scheduleDeferredLayout(
      taskId: task.id,
      sortMode: TaskSortMode.category,
    );
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
    _scheduleDeferredLayout(
      taskId: task.id,
      sortMode: TaskSortMode.priority,
    );
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
      if (!task.isInbox) {
        _scheduleDeferredLayout(
          taskId: task.id,
          sortMode: TaskSortMode.dueDate,
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    _cancelCompletion(task.id);
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
          authUser: widget.authService.currentUser,
          onSignOut: widget.authService.signOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final recentTasks = _recentlyAddedTasks();
    final pendingTasks = _filteredTasks(completed: false);
    final completedTasks = _filteredTasks(completed: true);
    final hasFilter = _searchQuery.isNotEmpty || _categoryFilterId != null;
    final hasVisibleTasks = recentTasks.isNotEmpty ||
        pendingTasks.isNotEmpty ||
        completedTasks.isNotEmpty;
    final showNoResults = !_isLoading && _tasks.isNotEmpty && !hasVisibleTasks && hasFilter;
    final showOrganizeButton =
        !_isLoading && !_isOrganizing && recentTasks.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: showOrganizeButton
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(
                onPressed: _isOrganizing ? null : _organizeRecentTasks,
                child: const Text('整理する'),
              ),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      controller: _inputController,
                      onSubmit: _registerTasks,
                      onFocusChanged: _onInputFocusChanged,
                    ),
                  ),
                  if (recentTasks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: GroupedTaskList(
                        title: '追加したタスク',
                        tasks: recentTasks,
                        categories: _categories,
                        showCompletedStyle: _showsCompletedStyle,
                        isRemoving: _isOrganizingTask,
                        isRegistrationFeedback: _isRegistrationFeedback,
                        showCompletionToggle: false,
                        openEditOnRowTap: true,
                        onToggle: _toggleTask,
                        onEdit: _showEditTaskSheet,
                        onDelete: _confirmDeleteTask,
                        onDismissDelete: _deleteTask,
                        onCategoryTap: _cycleCategory,
                        onPriorityTap: _cyclePriority,
                        onDueDateTap: _pickDueDate,
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
                      selectedId:
                          _categoryFilterId == CategoryItem.uncategorizedId
                              ? null
                              : _categoryFilterId,
                      onSelected: (id) {
                        setState(() => _categoryFilterId = id);
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
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
