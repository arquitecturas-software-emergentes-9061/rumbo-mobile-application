import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notification.dart';
import '../domain/notification_repository.dart';

/// State of the notification center of the signed-in visitor.
class NotificationCenterState {
  const NotificationCenterState({
    this.items = const [],
    this.unread = 0,
    this.total = 0,
    this.page = -1,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.sessionExpired = false,
    this.pendingReads = const {},
  });

  final List<AppNotification> items;

  /// Unread notifications of the account, for the badge. Reads shown here but
  /// not yet confirmed by the API are already discounted.
  final int unread;
  final int total;

  /// Last page loaded, or -1 before the first load.
  final int page;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool sessionExpired;

  /// Notifications read on this device whose read the API has not confirmed
  /// yet. They are sent again on the next refresh.
  final Set<String> pendingReads;

  bool get loaded => page >= 0;
  bool get hasMore => items.length < total;

  NotificationCenterState copyWith({
    List<AppNotification>? items,
    int? unread,
    int? total,
    int? page,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    bool? sessionExpired,
    Set<String>? pendingReads,
  }) => NotificationCenterState(
    items: items ?? this.items,
    unread: unread ?? this.unread,
    total: total ?? this.total,
    page: page ?? this.page,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : error ?? this.error,
    sessionExpired: sessionExpired ?? this.sessionExpired,
    pendingReads: pendingReads ?? this.pendingReads,
  );
}

/// Notification center (PR-370, PR-371, PR-382): reads the visitor's
/// notifications with the current session and keeps the read state in sync.
///
/// - A notification opened on this device is shown read at once. If the API
///   cannot confirm it, it stays read here and is sent again on [refresh], so
///   the badge never goes back up for something the visitor already saw.
/// - A notification the API no longer has is removed from the list.
/// - When the session cannot be renewed the state says so and nothing else is
///   requested until the visitor signs in again.
class NotificationCenterCubit extends Cubit<NotificationCenterState> {
  NotificationCenterCubit(
    this.repository, {
    this.pageSize = 20,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const NotificationCenterState());

  final NotificationRepository repository;
  final int pageSize;
  final DateTime Function() _clock;

  /// Loads the first page, after sending the reads still pending.
  Future<void> refresh() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    await _flushPendingReads();
    if (state.sessionExpired) return;
    try {
      final first = await repository.list(size: pageSize);
      if (isClosed) return;
      emit(
        state.copyWith(
          items: _withPendingReads(first.items),
          total: first.total,
          unread: _unreadCount(first.unread),
          page: 0,
          loading: false,
        ),
      );
    } on NotificationFailure catch (failure) {
      _fail(failure, loading: false);
    }
  }

  /// Appends the next page, if there is one.
  Future<void> loadMore() async {
    if (!state.loaded || !state.hasMore || state.loading || state.loadingMore) {
      return;
    }
    emit(state.copyWith(loadingMore: true, clearError: true));
    try {
      final next = await repository.list(page: state.page + 1, size: pageSize);
      if (isClosed) return;
      final known = state.items.map((item) => item.id).toSet();
      final fresh = next.items.where((item) => !known.contains(item.id));
      emit(
        state.copyWith(
          items: [...state.items, ..._withPendingReads(fresh)],
          total: next.total,
          unread: _unreadCount(next.unread),
          page: next.page,
          loadingMore: false,
        ),
      );
    } on NotificationFailure catch (failure) {
      _fail(failure, loadingMore: false);
    }
  }

  /// Shows the notification read now and confirms it with the API.
  Future<void> markRead(String id) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0 || state.items[index].isRead) return;
    final items = [...state.items];
    items[index] = items[index].markedRead(_clock());
    emit(
      state.copyWith(
        items: items,
        unread: state.unread > 0 ? state.unread - 1 : 0,
        pendingReads: {...state.pendingReads, id},
      ),
    );
    await _confirmRead(id);
  }

  /// Marks everything read here and in the API.
  Future<void> markAllRead() async {
    final now = _clock();
    final before = state;
    emit(
      state.copyWith(
        items: [for (final item in state.items) item.markedRead(now)],
        unread: 0,
        clearError: true,
      ),
    );
    try {
      await repository.markAllRead();
      if (!isClosed) emit(state.copyWith(pendingReads: const {}));
    } on NotificationFailure catch (failure) {
      if (isClosed) return;
      emit(
        before.copyWith(
          error: failure.message,
          sessionExpired: failure.sessionExpired,
        ),
      );
    }
  }

  Future<void> _confirmRead(String id) async {
    try {
      final stored = await repository.markRead(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          items: [
            for (final item in state.items) item.id == id ? stored : item,
          ],
          pendingReads: {...state.pendingReads}..remove(id),
        ),
      );
    } on NotificationFailure catch (failure) {
      if (isClosed) return;
      if (failure.notFound) {
        emit(
          state.copyWith(
            items: state.items.where((item) => item.id != id).toList(),
            total: state.total > 0 ? state.total - 1 : 0,
            pendingReads: {...state.pendingReads}..remove(id),
          ),
        );
        return;
      }
      // Kept read here and in pendingReads: the next refresh sends it again.
      emit(state.copyWith(sessionExpired: failure.sessionExpired));
    }
  }

  Future<void> _flushPendingReads() async {
    for (final id in [...state.pendingReads]) {
      await _confirmRead(id);
      if (state.sessionExpired) {
        emit(state.copyWith(loading: false, error: _expired));
        return;
      }
    }
  }

  List<AppNotification> _withPendingReads(Iterable<AppNotification> items) {
    final now = _clock();
    return [
      for (final item in items)
        state.pendingReads.contains(item.id) ? item.markedRead(now) : item,
    ];
  }

  int _unreadCount(int fromApi) {
    final count = fromApi - state.pendingReads.length;
    return count < 0 ? 0 : count;
  }

  void _fail(
    NotificationFailure failure, {
    bool? loading,
    bool? loadingMore,
  }) {
    if (isClosed) return;
    emit(
      state.copyWith(
        loading: loading,
        loadingMore: loadingMore,
        error: failure.message,
        sessionExpired: failure.sessionExpired,
      ),
    );
  }

  static const _expired = 'Tu sesión expiró. Inicia sesión de nuevo.';
}
