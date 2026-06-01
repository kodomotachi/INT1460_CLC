class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://lkkjiejhaltupvsxbfhi.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxra2ppZWpoYWx0dXB2c3hiZmhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NTYyNDIsImV4cCI6MjA5MTMzMjI0Mn0.GfePO510fNsMm3U1EGdkh_ZhLokWrJFvwtatk8hVROA';

  static const String restUrl = '$url/rest/v1';
  static const String postureTable = 'posture_events';
  static const String postureValueColumn = 'is_posture_correct';
  static const String timestampColumn = 'timestamp_ms';
}
