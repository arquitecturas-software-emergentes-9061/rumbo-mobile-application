/// Priority the API gives a notification: incidents of a site are [high].
enum NotificationPriority { normal, high }

/// A notification of the signed-in account, as the API's notification center
/// returns it. [title] and [message] come rendered by the API in Spanish, so
/// the app shows them as they are; [detail] is a datum, never display text.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.channel,
    required this.priority,
    required this.title,
    required this.message,
    required this.createdAt,
    this.siteId,
    this.detail,
    this.readAt,
  });

  final String id;
  final String type;
  final String channel;
  final NotificationPriority priority;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? siteId;
  final String? detail;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => isRead
      ? this
      : AppNotification(
          id: id,
          type: type,
          channel: channel,
          priority: priority,
          title: title,
          message: message,
          createdAt: createdAt,
          siteId: siteId,
          detail: detail,
          readAt: at,
        );
}

/// One page of the notification center. [unread] counts every unread
/// notification of the account, not only those of this page.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
    required this.unread,
  });

  final List<AppNotification> items;
  final int page;
  final int size;
  final int total;
  final int unread;

  bool get hasMore => (page + 1) * size < total;
}

/// The notification center could not be read or updated.
class NotificationFailure implements Exception {
  const NotificationFailure(
    this.message, {
    this.sessionExpired = false,
    this.notFound = false,
  });

  final String message;

  /// The notification does not exist for this account.
  final bool notFound;

  /// The session could not be renewed: the app must ask to sign in again.
  final bool sessionExpired;

  @override
  String toString() => message;
}
