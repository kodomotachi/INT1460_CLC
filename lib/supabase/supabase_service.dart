import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/posture_entry.dart';
import 'supabase_config.dart';

class SupabaseService {
  SupabaseService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Map<String, String> get _baseHeaders => <String, String>{
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      };

  Future<void> sendPosture(bool isGoodPosture) async {
    final Uri uri = _tableUri();
    final String body = jsonEncode(<String, dynamic>{
      SupabaseConfig.timestampColumn: DateTime.now().millisecondsSinceEpoch,
      SupabaseConfig.postureValueColumn: isGoodPosture,
    });

    final http.Response response = await _requestWithRetry(
      requestName: 'insert posture',
      makeRequest: () {
        return _httpClient.post(
          uri,
          headers: <String, String>{
            ..._baseHeaders,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: body,
        );
      },
    );

    if (!_isSuccess(response.statusCode)) {
      throw StateError(
        'Supabase insert failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<PostureEntry?> fetchLatestPosture() async {
    final List<PostureEntry> history = await fetchHistory(limit: 1);
    if (history.isEmpty) {
      return null;
    }
    return history.first;
  }

  Future<List<PostureEntry>> fetchHistory({int limit = 60}) async {
    final Uri uri = _tableUri(
      queryParameters: <String, String>{
        'select': [
          SupabaseConfig.timestampColumn,
          SupabaseConfig.postureValueColumn,
        ].join(','),
        'order': '${SupabaseConfig.timestampColumn}.desc',
        'limit': '$limit',
      },
    );

    final http.Response response = await _requestWithRetry(
      requestName: 'fetch posture history',
      makeRequest: () => _httpClient.get(uri, headers: _baseHeaders),
    );

    if (!_isSuccess(response.statusCode)) {
      throw StateError(
        'Supabase history fetch failed: ${response.statusCode} ${response.body}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Supabase history response is not a list.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> row) => PostureEntry.fromJson(
            row,
            valueColumn: SupabaseConfig.postureValueColumn,
            timestampColumn: SupabaseConfig.timestampColumn,
          ),
        )
        .toList(growable: false);
  }

  Future<http.Response> _requestWithRetry({
    required String requestName,
    required Future<http.Response> Function() makeRequest,
    int maxAttempts = 3,
  }) async {
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final http.Response response = await makeRequest();
        if (_isSuccess(response.statusCode)) {
          return response;
        }

        debugPrint(
          'Supabase $requestName failed '
          '($attempt/$maxAttempts): ${response.statusCode} ${response.body}',
        );

        lastError = StateError(
          'HTTP ${response.statusCode} while trying to $requestName',
        );
      } on Exception catch (error) {
        debugPrint(
          'Supabase $requestName error ($attempt/$maxAttempts): $error',
        );
        lastError = error;
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(
          Duration(milliseconds: 250 * attempt),
        );
      }
    }

    throw lastError ??
        StateError('Supabase $requestName failed without an error.');
  }

  Uri _tableUri({Map<String, String>? queryParameters}) {
    return Uri.parse(
      '${SupabaseConfig.restUrl}/${SupabaseConfig.postureTable}',
    ).replace(queryParameters: queryParameters);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;
}
