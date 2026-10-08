import 'dart:async';

/// Debounces rapid calls (search-as-you-type, form auto-save) so only the
/// last invocation within [delay] actually runs.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
