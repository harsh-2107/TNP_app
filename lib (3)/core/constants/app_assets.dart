/// Centralized asset path registry. Widgets should reference
/// `AppAssets.logo`, never a raw `'assets/...'` string literal.
class AppAssets {
  const AppAssets._();

  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _animations = 'assets/animations';

  static const String logo = '$_images/logo.png';
  static const String googleIcon = '$_icons/google.svg';
  static const String emptyState = '$_animations/empty_state.json';
}
