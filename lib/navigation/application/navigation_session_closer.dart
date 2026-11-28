/// How a navigation session ended, for the session record.
enum NavigationEnding { arrived, cancelled }

/// Closes a navigation session exactly once (PR-346).
///
/// The arrival sheet, the back button and leaving the AR activity can all try
/// to finish the same session, sometimes at the same time. Only the first
/// call runs [close]; later calls, including concurrent ones, wait for that
/// same result. If [close] fails, the next call may try again.
class NavigationSessionCloser {
  NavigationSessionCloser(this._close);

  final Future<void> Function(String sessionId, NavigationEnding ending) _close;
  final Map<String, Future<void>> _closing = {};
  final Set<String> _closed = {};

  bool isClosed(String sessionId) => _closed.contains(sessionId);

  /// Closes [sessionId] with [ending]. Returns `true` only for the call that
  /// actually closed it.
  Future<bool> close(String sessionId, NavigationEnding ending) async {
    if (sessionId.isEmpty || _closed.contains(sessionId)) return false;
    final running = _closing[sessionId];
    if (running != null) {
      await running;
      return false;
    }
    final attempt = _close(sessionId, ending);
    _closing[sessionId] = attempt;
    try {
      await attempt;
      _closed.add(sessionId);
      return true;
    } finally {
      _closing.remove(sessionId);
    }
  }
}
