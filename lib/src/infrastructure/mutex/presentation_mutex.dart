import '../logging/platform_ad_logger.dart';

/// Mutual-exclusion coordinator guaranteeing single full-screen presentation.
///
/// Prevents overlapping presentations between App Open, Interstitial, and Paywall ads.
class PresentationMutex {
  final PlatformAdLogger? _logger;
  String? _currentHolderId;
  DateTime? _lastAdDismissedAt;
  bool _isResumingFromAd = false;

  PresentationMutex([this._logger]);

  /// Returns true if a full-screen ad is currently holding the presentation lock.
  bool get isLocked => _currentHolderId != null;

  /// ID of the placement or component currently holding the lock.
  String? get currentHolderId => _currentHolderId;

  /// Timestamp when the most recent fullscreen ad was dismissed.
  DateTime? get lastAdDismissedAt => _lastAdDismissedAt;

  /// Whether the app is resuming as a direct result of dismissing a fullscreen ad.
  bool get isResumingFromAd => _isResumingFromAd;

  /// Clears the [isResumingFromAd] flag once the post-dismissal resume cycle is consumed.
  void consumeResumeFromAd() {
    if (_isResumingFromAd) {
      _isResumingFromAd = false;
      _logger?.debug('[Mutex] Consumed post-ad resume suppression.');
    }
  }

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
    _isResumingFromAd = true;
    _logger?.info('[Mutex] 🔒 Presentation lock ACQUIRED by "$holderId".');
    return true;
  }

  /// Releases the lock if held by [holderId].
  void release(String holderId) {
    if (_currentHolderId == holderId) {
      _currentHolderId = null;
      _lastAdDismissedAt = DateTime.now();
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
      _lastAdDismissedAt = DateTime.now();
    }
  }
}
