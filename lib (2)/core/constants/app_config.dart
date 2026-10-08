/// Environment-specific configuration.
///
/// Values are supplied at build/run time via `--dart-define`, e.g.:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=xxxx \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=966620190898-d9f1a5q8666lp1mllab2cr68bb8qd63i.apps.googleusercontent.com
/// ```
///
class AppConfig {
  const AppConfig._();

  static const Environment environment = Environment.development;

  static const String appName = 'IIIT Nagpur Placement Cell';

  static const String supabaseUrl = 'https://vyghlmxfyjsukkpqejfi.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_oVjsp2S93N15rrZkPrT3Gw_TEWDmJ2z';
  static const String googleServerClientId =
      '966620190898-7e9lpss1b2rrm920tqjrmkcm0ptcmg3i.apps.googleusercontent.com';

  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'https://crispr-tnp.onrender.com',
  );

  static const String resumeBucket = 'resumes';
  static const int maxResumeSizeBytes = 2 * 1024 * 1024; // 2 MB

  static bool get isProduction => environment == Environment.production;
  static bool get isDevelopment => environment == Environment.development;
}

enum Environment { development, staging, production }
