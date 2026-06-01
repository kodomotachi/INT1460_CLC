import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/posture_entry.dart';
import '../models/posture_view_state.dart';
import '../supabase/supabase_service.dart';

class PostureRepository extends ChangeNotifier {
  PostureRepository._();

  static final PostureRepository instance = PostureRepository._();

  final SupabaseService _supabaseService = SupabaseService();

  Timer? _cooldownTimer;
  Timer? _pollTimer;
  bool _started = false;
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
    } on Exception catch (error) {
      _lastErrorMessage = '$error';
      debugPrint('Posture refresh failed: $error');
    } finally {
      _refreshInProgress = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

bool _isWidgetTestBinding() {
  final String bindingDescription = WidgetsBinding.instance.toString();
  return bindingDescription.contains('AutomatedTestWidgetsFlutterBinding') ||
      bindingDescription.contains('LiveTestWidgetsFlutterBinding');
}
