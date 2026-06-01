import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/posture_view_state.dart';
import '../posture/posture_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PostureRepository _repository = PostureRepository.instance;
  final AudioPlayer _voicePlayer = AudioPlayer();
  PostureViewState? _lastVoiceState;

  @override
  void initState() {
    super.initState();
    _voicePlayer.audioCache = AudioCache(prefix: '');
    _repository.addListener(_handleRepositoryUpdate);
    _configureVoice();
  }

  Future<void> _configureVoice() async {
    await _voicePlayer.setReleaseMode(ReleaseMode.stop);
    await _voicePlayer.setVolume(1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleRepositoryUpdate();
    });
  }

  void _handleRepositoryUpdate() {
    final PostureViewState viewState = _repository.viewState;
    if (viewState == _lastVoiceState) {
      return;
    }

    _lastVoiceState = viewState;
    unawaited(_playVoiceForState(viewState));
  }

  Future<void> _playVoiceForState(PostureViewState viewState) async {
    final String voiceAssetPath = switch (viewState) {
      PostureViewState.good => 'lib/voices/goodPostureVoice.flac',
      PostureViewState.bad => 'lib/voices/badPostureVoice.flac',
      PostureViewState.noData => 'lib/voices/noDataVoice.flac',
    };

    final String cachedPath = await _voicePlayer.audioCache.loadPath(
      voiceAssetPath,
    );

    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(
        DeviceFileSource(cachedPath, mimeType: 'audio/flac'),
      );
    } on Exception catch (error) {
      debugPrint('Voice playback failed for $voiceAssetPath: $error');
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_handleRepositoryUpdate);
    _voicePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (BuildContext context, Widget? child) {
        final PostureViewState postureState = _repository.viewState;
        final Color accentColor = switch (postureState) {
          PostureViewState.good => const Color(0xFF4ADE80),
          PostureViewState.bad => const Color(0xFFFF6B9A),
          PostureViewState.noData => const Color(0xFF7DD3FC),
        };

        final String postureImagePath = switch (postureState) {
          PostureViewState.good => 'lib/images/correctPosture.png',
          PostureViewState.bad => 'lib/images/incorrectPosture.png',
          PostureViewState.noData => 'lib/images/noDataPosture.png',
        };

        return Scaffold(
          backgroundColor: const Color(0xFF090B10),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 0.95,
                        colors: [
                          accentColor.withValues(alpha: 0.28),
                          const Color(0xFF090B10),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              maxWidth: 320,
                              maxHeight: 360,
                            ),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11141B),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.18),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              postureImagePath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _repository.currentStateLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Latest posture event from Supabase',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _buildRefreshLabel(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.56),
                          ),
                        ),
                        if (_repository.lastErrorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _repository.lastErrorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFB3C7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildRefreshLabel() {
    final DateTime? lastUpdatedAt = _repository.lastUpdatedAt;
    if (lastUpdatedAt == null) {
      return 'Refreshing every second after startup';
    }

    final String hour = lastUpdatedAt.hour.toString().padLeft(2, '0');
    final String minute = lastUpdatedAt.minute.toString().padLeft(2, '0');
    final String second = lastUpdatedAt.second.toString().padLeft(2, '0');
    return 'Refreshing every second • Last updated $hour:$minute:$second';
  }
}
