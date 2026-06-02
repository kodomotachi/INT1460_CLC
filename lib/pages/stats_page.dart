import 'package:flutter/material.dart';

import '../models/posture_entry.dart';
import '../posture/posture_repository.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PostureRepository repository = PostureRepository.instance;

    return AnimatedBuilder(
      animation: repository,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F1),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Recent posture events',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172017),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rows from Supabase table `posture_events`',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4D5B4D),
                  ),
                ),
                const SizedBox(height: 20),
                if (repository.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No posture history yet'),
                    ),
                  )
                else
                  ...repository.history.map(
                    (PostureEntry entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryRow(entry: entry),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final PostureEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color color =
        entry.isGoodPosture ? const Color(0xFF177245) : const Color(0xFFC33D64);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.isGoodPosture ? 'Good posture' : 'Bad posture',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF172017),
              ),
            ),
          ),
          Text(
            _formatTimestamp(entry.timestampMs),
            style: const TextStyle(
              color: Color(0xFF5D6B5D),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestampMs) {
    final Duration duration = Duration(milliseconds: timestampMs);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
