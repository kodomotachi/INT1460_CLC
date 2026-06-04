import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/posture_entry.dart';
import '../models/posture_view_state.dart';
import '../notifications/android_background_posture_service.dart';
import '../notifications/posture_notification_service.dart';
import '../supabase/supabase_service.dart';

class PostureRepository extends ChangeNotifier with WidgetsBindingObserver {
  PostureRepository._();

  static final PostureRepository instance = PostureRepository._();

  final SupabaseService _supabaseService = SupabaseService();
  final PostureNotificationService _notificationService =
      PostureNotificationService.instance;

  Timer? _cooldownTimer;
  Timer? _pollTimer;
  bool _started = false;
  bool _observingLifecycle = false;
  bool _cooldownCompleted = false;
  bool _refreshInProgress = false;
  List<PostureEntry> _history = const <PostureEntry>[];
  String? _lastErrorMessage;
  DateTime? _lastUpdatedAt;

  bool get isCoolingDown => _started && !_cooldownCompleted;
  List<PostureEntry> get history => _history;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  PostureEntry? get latestPosture => _history.isEmpty ? null : _history.first;

  PostureViewState get viewState {
    if (isCoolingDown || latestPosture == null) {
      return PostureViewState.noData;
    }

    return latestPosture!.isGoodPosture
        ? PostureViewState.good
        : PostureViewState.bad;
  }

  String get currentStateLabel {
    return switch (viewState) {
      PostureViewState.good => 'Good posture',
      PostureViewState.bad => 'Bad posture',
      PostureViewState.noData => isCoolingDown
          ? 'Starting live posture sync'
          : 'No posture data',
    };
  }

  void start() {
    if (_started) {
      return;
    }

    _started = true;
    if (!_isWidgetTestBinding()) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
      unawaited(_notificationService.initialize());
    }
    notifyListeners();

    if (_isWidgetTestBinding()) {
      _cooldownCompleted = true;
      notifyListeners();
      return;
    }

    _cooldownTimer = Timer(const Duration(seconds: 3), () {
      _cooldownCompleted = true;
      notifyListeners();
      unawaited(refresh());
      _pollTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(refresh()),
      );
    });
  }

  Future<void> refresh() async {
    if (_refreshInProgress) {
      return;
    }

    _refreshInProgress = true;

    try {
      _history = await _supabaseService.fetchHistory(limit: 25);
      _lastErrorMessage = null;
      _lastUpdatedAt = DateTime.now();
      unawaited(_notificationService.handleLatestPosture(latestPosture));
    } on Exception catch (error) {
      _lastErrorMessage = '$error';
      debugPrint('Posture refresh failed: $error');
    } finally {
      _refreshInProgress = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AndroidBackgroundPostureService.stop());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(AndroidBackgroundPostureService.start());
    }

    _notificationService.setAppInForeground(
      state == AppLifecycleState.resumed,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    super.dispose();
  }
}

bool _isWidgetTestBinding() {
  final String bindingDescription = WidgetsBinding.instance.toString();
  return bindingDescription.contains('AutomatedTestWidgetsFlutterBinding') ||
      bindingDescription.contains('LiveTestWidgetsFlutterBinding');
}
