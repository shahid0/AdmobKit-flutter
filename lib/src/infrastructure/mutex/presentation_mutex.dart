import '../logging/platform_ad_logger.dart';

/// Mutual-exclusion coordinator guaranteeing single full-screen presentation.
///
/// Prevents overlapping presentations between App Open, Interstitial, and Paywall ads.
class PresentationMutex {
  final PlatformAdLogger? _logger;
  String? _currentHolderId;

  PresentationMutex([this._logger]);

  /// Returns true if a full-screen ad is currently holding the presentation lock.
  bool get isLocked => _currentHolderId != null;

  /// ID of the placement or component currently holding the lock.
  String? get currentHolderId => _currentHolderId;

  /// Attempts to acquire the presentation lock for [holderId].
  ///
  /// Returns `true` if lock was successfully acquired.
  /// Returns `false` if another ad is already active, rejecting collision.
  bool tryAcquire(String holderId) {
    if (_currentHolderId != null) {
      _logger?.warning(
        '[Mutex] Presentation lock collision! "$holderId" rejected because '
        '"$_currentHolderId" is currently active.',
      );
      return false;
    }

    _currentHolderId = holderId;
    _logger?.info('[Mutex] 🔒 Presentation lock ACQUIRED by "$holderId".');
    return true;
  }

  /// Releases the lock if held by [holderId].
  void release(String holderId) {
    if (_currentHolderId == holderId) {
      _currentHolderId = null;
      _logger?.info('[Mutex] 🔓 Presentation lock RELEASED by "$holderId".');
    } else {
      _logger?.warning(
        '[Mutex] Attempted to release lock for "$holderId", but lock is held by "$_currentHolderId".',
      );
    }
  }

  /// Force-clears the lock in case of uncaught native dismissals.
  void forceRelease() {
    if (_currentHolderId != null) {
      _logger?.warning('[Mutex] ⚠️ Force-releasing presentation lock from "$_currentHolderId".');
      _currentHolderId = null;
    }
  }
}
