class PostureEntry {
  const PostureEntry({
    required this.timestampMs,
    required this.isGoodPosture,
  });

  final int timestampMs;
  final bool isGoodPosture;

  factory PostureEntry.fromJson(
    Map<String, dynamic> json, {
    required String valueColumn,
    required String timestampColumn,
  }) {
    final Object? rawTimestamp = json[timestampColumn];

    return PostureEntry(
      timestampMs: switch (rawTimestamp) {
        int value => value,
        String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
      isGoodPosture: json[valueColumn] as bool? ?? false,
    );
  }
}
