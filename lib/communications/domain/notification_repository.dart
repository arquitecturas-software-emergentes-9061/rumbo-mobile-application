import 'notification.dart';

/// Notification center of the signed-in account (PR-382, PR-383). Every call
/// uses the current session; no call can name another account.
abstract interface class NotificationRepository {
  /// Newest first. Throws [NotificationFailure].
  Future<NotificationPage> list({
    bool unreadOnly = false,
    int page = 0,
    int size = 20,
  });

  /// Marks one notification read and returns it as the API stored it. Marking
  /// it twice keeps the first read instant. Throws [NotificationFailure].
  Future<AppNotification> markRead(String id);

  /// Marks every unread notification read and returns how many changed.
  /// Throws [NotificationFailure].
  Future<int> markAllRead();
}
