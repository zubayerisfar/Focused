import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central Ad Service managing Google AdMob ad units (Banner, Interstitial & Rewarded Ads)
class AdService {
  static final AdService instance = AdService._internal();
  factory AdService() => instance;
  AdService._internal();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  // Google AdMob Test Ad Unit IDs (guaranteed to always serve test ads safely during development)
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';

  // Production Ad Unit IDs from AdMob console
  static const String _prodBannerAndroid =
      'ca-app-pub-7510036527454914/9565306853';
  static const String _prodInterstitialAndroid =
      'ca-app-pub-7510036527454914/8366056625';
  static const String _prodRewardedAndroid =
      'ca-app-pub-7510036527454914/4550829496';

  String get bannerAdUnitId {
    if (kDebugMode) return _testBannerAndroid;
    return _prodBannerAndroid;
  }

  String get interstitialAdUnitId {
    if (kDebugMode) return _testInterstitialAndroid;
    return _prodInterstitialAndroid;
  }

  String get rewardedAdUnitId {
    if (kDebugMode) return _testRewardedAndroid;
    return _prodRewardedAndroid;
  }

  /// Initialize MobileAds SDK and pre-cache ads
  Future<void> initialize() async {
    if (_initialized) return;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await MobileAds.instance.initialize();
        _initialized = true;
        debugPrint('Google Mobile Ads initialized successfully.');
        loadInterstitialAd();
        loadRewardedAd();
      } catch (e) {
        debugPrint('Google Mobile Ads initialization failed: $e');
      }
    }
  }

  // ===========================================================================
  // INTERSTITIAL ADS (Full-Screen 30s / Video / Graphic)
  // ===========================================================================

  void loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('Interstitial Ad preloaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('Interstitial Ad failed to load: $error');
        },
      ),
    );
  }

  /// Shows the preloaded interstitial ad
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready yet, loading for next time.');
      loadInterstitialAd();
      onAdClosed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next one
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdClosed?.call();
      },
    );

    _interstitialAd!.show();
  }

  // ===========================================================================
  // REWARDED ADS (30s Video for Bonus Unlocks / Rewards)
  // ===========================================================================

  void loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('Rewarded Ad preloaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          debugPrint('Rewarded Ad failed to load: $error');
        },
      ),
    );
  }

  /// Shows the preloaded rewarded video ad
  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('Rewarded ad not ready yet, loading for next time.');
      loadRewardedAd();
      onAdDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next one
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (adWithoutView, reward) {
        onUserEarnedReward(reward);
      },
    );
  }
}
