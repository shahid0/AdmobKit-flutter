import 'dart:async';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../logging/platform_ad_logger.dart';

/// Configuration for consent testing (e.g. simulating EEA geography or test devices).
class ConsentTestConfig {
  /// The simulated debug geography for testing GDPR/EEA regulations.
  final DebugGeography debugGeography;

  /// The list of test device identifiers for consent testing.
  final List<String> testIdentifiers;

  /// Creates a [ConsentTestConfig] with optional debug geography and test device IDs.
  const ConsentTestConfig({
    this.debugGeography = DebugGeography.debugGeographyDisabled,
    this.testIdentifiers = const [],
  });
}

/// Orchestrates Google UMP (User Messaging Platform) and Apple ATT (App Tracking Transparency).
class ConsentCoordinator {
  final PlatformAdLogger? _logger;

  ConsentCoordinator([this._logger]);

  /// Executes the full consent pipeline:
  /// 1. Updates Google UMP consent info.
  /// 2. Loads and displays UMP consent form if required (EEA/UK/Switzerland).
  /// 3. Prompts Apple ATT permission dialog if on iOS.
  /// 4. Verifies whether ads can be requested.
  Future<bool> gatherConsent({
    ConsentTestConfig? testConfig,
  }) async {
    _logger?.info('[Consent] 🛡️ Starting consent gathering pipeline...');

    try {
      final completer = Completer<void>();
      final params = ConsentRequestParameters(
        consentDebugSettings: testConfig != null
            ? ConsentDebugSettings(
                debugGeography: testConfig.debugGeography,
                testIdentifiers: testConfig.testIdentifiers,
              )
            : null,
      );

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          _logger?.debug('[Consent] UMP consent info updated successfully.');
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              _logger?.warning(
                '[Consent] UMP form dismissed with error: [${formError.errorCode}] ${formError.message}',
              );
            } else {
              _logger?.debug('[Consent] UMP consent form resolved.');
            }
            if (!completer.isCompleted) completer.complete();
          });
        },
        (FormError error) {
          _logger?.warning(
            '[Consent] UMP requestConsentInfoUpdate failed: [${error.errorCode}] ${error.message}',
          );
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logger?.warning('[Consent] UMP consent update timed out. Continuing...');
        },
      );
    } catch (e, st) {
      _logger?.error('[Consent] Unexpected error during UMP consent', e, st);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          _logger?.info('[Consent] Prompting iOS App Tracking Transparency (ATT)...');
          final newStatus = await AppTrackingTransparency.requestTrackingAuthorization();
          _logger?.info('[Consent] iOS ATT response status: $newStatus');
        } else {
          _logger?.debug('[Consent] iOS ATT already resolved with status: $status');
        }
      } catch (e, st) {
        _logger?.error('[Consent] Error requesting ATT authorization', e, st);
      }
    }

    final canRequest = await ConsentInformation.instance.canRequestAds();
    _logger?.info('[Consent] Final consent resolution: canRequestAds = $canRequest');
    return canRequest;
  }

  /// Returns true if the user requires a privacy options link in the app (e.g. in settings).
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Presents the Google UMP privacy options form so users can change their consent settings.
  Future<bool> showPrivacyOptionsForm() async {
    final completer = Completer<bool>();
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          _logger?.warning(
            '[Consent] Privacy options form error: [${formError.errorCode}] ${formError.message}',
          );
          completer.complete(false);
        } else {
          _logger?.info('[Consent] Privacy options updated by user.');
          completer.complete(true);
        }
      });
    } catch (e) {
      _logger?.warning('[Consent] Failed to present privacy options form: $e');
      return false;
    }
    return completer.future;
  }
}
