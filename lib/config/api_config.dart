class ApiConfig {
  // Single source of truth — our custom backend on ott.redapp.space
  static String baseUrl = "https://ott.redapp.space/redapp/api";
  static String apiKey = "ku9qFY6XKp5OC1bG";

  static String get authUrl      => "$baseUrl/auth.php";
  static String get homeUrl      => "$baseUrl/home.php";
  static String get contentUrl   => "$baseUrl/content.php";
  static String get detailsUrl   => "$baseUrl/details.php";
  static String get streamtapeUrl=> "$baseUrl/streamtape_resolver.php";
  static String get linkHealthUrl=> "$baseUrl/link_health.php";
  static String get adminUrl     => "$baseUrl/admin_api.php";
  static String get downloadProxyUrl => "$baseUrl/download_proxy.php";

  static Map<String, String> get headers => {
    'x-api-key': apiKey,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  };
}
