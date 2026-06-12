import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

/// Thin wrapper around Appodeal so you can copy this file
/// into another project and call a small set of functions.
///
/// Note: native setup (Android/iOS) + pubspec dependency is still required.
class AppodealAds {
  static bool _initialized = false;
  static String? _appKey;

  static VoidCallback? _pendingRewardCallback;
  static VoidCallback? _onRewardShowFailed;
  static Completer<void>? _rewardedLoadCompleter;

  static bool get isInitialized => _initialized;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String _placement(String? placement) =>
      (placement == null || placement.isEmpty) ? 'default' : placement;

  static void _registerRewardedCallbacks() {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {
        if (!isPrecache) {
          _rewardedLoadCompleter?.complete();
          _rewardedLoadCompleter = null;
        }
      },
      onRewardedVideoFailedToLoad: () {
        _rewardedLoadCompleter?.completeError(StateError('failed to load'));
        _rewardedLoadCompleter = null;
        Appodeal.cache(AppodealAdType.RewardedVideo);
      },
      onRewardedVideoShown: () {},
      onRewardedVideoShowFailed: () {
        _onRewardShowFailed?.call();
        _pendingRewardCallback = null;
        _onRewardShowFailed = null;
        Appodeal.cache(AppodealAdType.RewardedVideo);
      },
      onRewardedVideoFinished: (_, __) {},
      onRewardedVideoClosed: (isFinished) {
        if (isFinished) {
          _pendingRewardCallback?.call();
        }
        _pendingRewardCallback = null;
        _onRewardShowFailed = null;
        Appodeal.cache(AppodealAdType.RewardedVideo);
      },
      onRewardedVideoExpired: () {
        Appodeal.cache(AppodealAdType.RewardedVideo);
      },
      onRewardedVideoClicked: () {},
    );
  }

  static Future<void> initialize({
    required String appKey,
    List<AppodealAdType> adTypes = const [
      AppodealAdType.Interstitial,
      AppodealAdType.RewardedVideo,
      AppodealAdType.Banner,
      AppodealAdType.MREC,
    ],
    bool testing = false,
    bool verboseLogs = false,
  }) async {
    if (!_supported || _initialized) return;
    _appKey = appKey;

    Appodeal.setTesting(testing);
    if (verboseLogs) {
      Appodeal.setLogLevel(Appodeal.LogLevelVerbose);
    }

    _registerRewardedCallbacks();

    final initCompleter = Completer<void>();
    Appodeal.initialize(
      appKey: appKey,
      adTypes: adTypes,
      onInitializationFinished: (errors) {
        if (errors != null && errors.isNotEmpty) {
          debugPrint(
            'Appodeal init errors: ${errors.map((e) => e.description).join(', ')}',
          );
        }
        if (!initCompleter.isCompleted) initCompleter.complete();
      },
    );

    await initCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('Appodeal initialize timed out after 30s');
      },
    );

    _initialized = true;
    Appodeal.cache(AppodealAdType.RewardedVideo);
  }

  static Future<bool> canShowInterstitial({String? placement}) async {
    if (!_supported || !_initialized) return false;
    return Appodeal.canShow(
      AppodealAdType.Interstitial,
      _placement(placement),
    );
  }

  static Future<void> showInterstitial({String? placement}) async {
    if (!_supported || !_initialized) return;
    final p = _placement(placement);
    if (!await canShowInterstitial(placement: p)) return;
    await Appodeal.show(AppodealAdType.Interstitial, p);
  }

  static Future<bool> canShowRewarded({String? placement}) async {
    if (!_supported || !_initialized) return false;
    return Appodeal.canShow(
      AppodealAdType.RewardedVideo,
      _placement(placement),
    );
  }

  static void cacheRewarded() {
    if (!_supported || !_initialized) return;
    Appodeal.cache(AppodealAdType.RewardedVideo);
  }

  static Future<String?> _resolveReadyPlacement(String placement) async {
    if (await canShowRewarded(placement: placement)) return placement;
    if (placement != 'default' && await canShowRewarded(placement: 'default')) {
      return 'default';
    }
    return null;
  }

  static Future<String?> _waitForRewardedPlacement(
    String placement, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ready = await _resolveReadyPlacement(placement);
    if (ready != null) return ready;

    cacheRewarded();
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final resolved = await _resolveReadyPlacement(placement);
      if (resolved != null) return resolved;

      _rewardedLoadCompleter ??= Completer<void>();
      try {
        await _rewardedLoadCompleter!.future.timeout(
          const Duration(seconds: 2),
        );
      } on TimeoutException {
        // Keep polling until the overall deadline.
      } catch (_) {
        _rewardedLoadCompleter = null;
      } finally {
        _rewardedLoadCompleter = null;
      }

      cacheRewarded();
    }

    return null;
  }

  /// Shows a rewarded ad. Returns `true` if the show call was made.
  static Future<bool> showRewarded({
    String? placement,
    VoidCallback? onRewarded,
    VoidCallback? onUnavailable,
    VoidCallback? onShowFailed,
  }) async {
    if (!_supported || !_initialized) {
      onUnavailable?.call();
      return false;
    }

    final requested = _placement(placement);
    final readyPlacement = await _waitForRewardedPlacement(requested);
    if (readyPlacement == null) {
      cacheRewarded();
      onUnavailable?.call();
      return false;
    }

    _pendingRewardCallback = onRewarded;
    _onRewardShowFailed = onShowFailed;

    final shown = await Appodeal.show(AppodealAdType.RewardedVideo, readyPlacement);
    if (!shown) {
      _pendingRewardCallback = null;
      _onRewardShowFailed = null;
      cacheRewarded();
      onShowFailed?.call();
      return false;
    }
    return true;
  }

  static Widget bannerWidget({
    String placement = 'default',
  }) {
    if (!_supported || !_initialized) return const SizedBox.shrink();
    return SizedBox(
      height: 50,
      child: AppodealBanner(
        adSize: AppodealBannerSize.BANNER,
        placement: placement,
      ),
    );
  }

  static void showBannerBottom() {
    if (!_supported || !_initialized) return;
    Appodeal.show(AppodealAdType.BannerBottom);
  }

  static void showBannerTop() {
    if (!_supported || !_initialized) return;
    Appodeal.show(AppodealAdType.BannerTop);
  }

  static void hideBanners() {
    if (!_supported || !_initialized) return;
    Appodeal.hide(AppodealAdType.BannerTop);
    Appodeal.hide(AppodealAdType.BannerBottom);
  }

  static void destroyBanners() {
    if (!_supported || !_initialized) return;
    Appodeal.destroy(AppodealAdType.Banner);
  }

  static Future<void> revokeConsent() async {
    if (!_supported || !_initialized) return;
    Appodeal.ConsentForm.revoke();
  }

  static Future<void> loadAndShowConsentIfRequired() async {
    if (!_supported || !_initialized) return;
    final key = _appKey;
    if (key == null || key.isEmpty) return;

    final consentCompleter = Completer<void>();
    Appodeal.ConsentForm.loadAndShowIfRequired(
      appKey: key,
      onConsentFormDismissed: (_) {
        cacheRewarded();
        if (!consentCompleter.isCompleted) consentCompleter.complete();
      },
    );

    await consentCompleter.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        debugPrint('Appodeal consent timed out after 120s');
      },
    );
  }
}
