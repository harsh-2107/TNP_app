/// Small, dependency-free string helpers used across forms/validators.
extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$').hasMatch(trim());

  bool get isValidCollegeEmail =>
      isValidEmail && toLowerCase().endsWith('.ac.in');

  bool get isValidIndianPhone =>
      RegExp(r'^(\+91[\-\s]?)?[6-9]\d{9}$').hasMatch(trim());

  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String get initials {
    final parts = trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String truncate(int maxLength) =>
      length <= maxLength ? this : '${substring(0, maxLength)}…';
}

extension NullableStringX on String? {
  bool get isNullOrEmpty => this == null || this!.trim().isEmpty;
}
