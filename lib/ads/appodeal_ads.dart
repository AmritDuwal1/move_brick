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

  static bool get isInitialized => _initialized;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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

    await Appodeal.initialize(
      appKey: appKey,
      adTypes: adTypes,
      onInitializationFinished: (_) {},
    );
    _initialized = true;
  }

  static Future<bool> canShowInterstitial() async {
    if (!_supported || !_initialized) return false;
    return Appodeal.canShow(AppodealAdType.Interstitial);
  }

  static Future<void> showInterstitial({String? placement}) async {
    if (!_supported || !_initialized) return;
    if (!await canShowInterstitial()) return;
    if (placement == null || placement.isEmpty) {
      Appodeal.show(AppodealAdType.Interstitial);
    } else {
      Appodeal.show(AppodealAdType.Interstitial, placement);
    }
  }

  static Future<bool> canShowRewarded() async {
    if (!_supported || !_initialized) return false;
    return Appodeal.canShow(AppodealAdType.RewardedVideo);
  }

  static Future<void> showRewarded({String? placement}) async {
    if (!_supported || !_initialized) return;
    if (!await canShowRewarded()) return;
    if (placement == null || placement.isEmpty) {
      Appodeal.show(AppodealAdType.RewardedVideo);
    } else {
      Appodeal.show(AppodealAdType.RewardedVideo, placement);
    }
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
    Appodeal.ConsentForm.loadAndShowIfRequired(
      appKey: key,
      onConsentFormDismissed: (_) {},
    );
  }
}

