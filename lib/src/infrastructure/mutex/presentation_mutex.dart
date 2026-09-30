import 'dart:async';
import '../logging/platform_ad_logger.dart';

/// Mutual-exclusion coordinator guaranteeing single full-screen presentation.
///
/// Prevents overlapping presentations between App Open, Interstitial, and Paywall ads.
class PresentationMutex {
  final PlatformAdLogger? _logger;
  PresentationToken? _holder;
  final _changes = StreamController<void>.broadcast();
  bool _disposed = false;

  PresentationMutex([this._logger]);

  /// Returns true if a full-screen ad is currently holding the presentation lock.
  bool get isLocked => _holder != null;

  /// ID of the placement or component currently holding the lock.
  String? get currentHolderId => _holder?.holderId;

  /// Asynchronous state notifications; consumers recheck ownership on delivery.
  Stream<void> get changes => _changes.stream;

  bool owns(PresentationToken token) => identical(_holder, token);

  /// Attempts to acquire the presentation lock for [holderId].
  ///
  /// Returns an exclusive token, or null if another presentation owns the lock.
  PresentationToken? tryAcquire(String holderId) {
    if (_disposed) return null;
    if (_holder != null) {
      _logger?.warning(
        '[Mutex] Presentation lock collision! "$holderId" rejected because '
        '"$currentHolderId" is currently active.',
      );
      return null;
    }

    final token = PresentationToken._(holderId);
    _holder = token;
    _changes.add(null);
    _logger?.info('[Mutex] 🔒 Presentation lock ACQUIRED by "$holderId".');
    return token;
  }

  /// Releases only this acquisition. Late callbacks cannot release a newer one.
  void release(PresentationToken token) {
    if (!identical(_holder, token)) return;
    _holder = null;
    _changes.add(null);
    _logger?.info('[Mutex] 🔓 Presentation lock RELEASED by "${token.holderId}".');
  }

  /// Force-clears the lock in case of uncaught native dismissals.
  void forceRelease() {
    if (_holder != null) {
      _logger?.warning('[Mutex] ⚠️ Force-releasing presentation lock from "$currentHolderId".');
      _holder = null;
      _changes.add(null);
    }
  }

  /// Ends this session's presentation lifetime. Late holders cannot reacquire.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    forceRelease();
    unawaited(_changes.close());
  }
}

/// Identity of a single acquisition, not merely the placement that requested it.
final class PresentationToken {
  final String holderId;

  PresentationToken._(this.holderId);
}
