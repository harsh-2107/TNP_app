/// Relative-time formatting used by notification cards ("5 minutes ago").
extension DateTimeX on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    final weeks = (diff.inDays / 7).floor();
    if (diff.inDays < 30) return '$weeks week${weeks == 1 ? '' : 's'} ago';
    final months = (diff.inDays / 30).floor();
    if (diff.inDays < 365) return '$months month${months == 1 ? '' : 's'} ago';
    final years = (diff.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[month - 1]} $day, $year';
  }
}
