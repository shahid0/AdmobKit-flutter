/// Readiness of the consent and SDK pipeline, separate from individual ads.
enum AdInitializationState {
  /// Call AdmobKit.initialize before requesting ads.
  uninitialized,

  /// UMP and (on iOS) ATT are still resolving.
  gatheringConsent,

  /// The SDK and native ad factories are still initializing.
  initializingSdk,

  /// Privacy choices are being updated. Ad requests are suspended.
  updatingConsent,

  /// Initialization completed. Premium entitlement can still suppress ads.
  ready,

  /// UMP resolved and does not allow ad requests.
  consentDenied,

  /// Initialization failed; no requests will be started.
  failed,

  /// This session was disposed and pending callers were released.
  disposed,
}
