class AppConfig {
  // Replace with your Cloud Run service URL after deployment
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  static const String apiBase = '$baseUrl/api';

  static Duration get uploadSignedUrlExpiry => const Duration(hours: 2);
  static Duration get pollingInterval => const Duration(seconds: 5);
  static int get pollingMaxAttempts => 120; // 10 minutes
}
