import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'database_service.dart';

/// Entitlement identifier configured in RevenueCat dashboard.
const _entitlementId = 'premium';

/// Snapshot of the "premium" entitlement with the real plan and expiry,
/// derived from RevenueCat [CustomerInfo].
class PremiumStatus {
  final bool isPremium;

  /// 'free', 'monthly', 'yearly' or 'trial'
  final String plan;

  /// Subscription expiry (null when not premium or non-expiring).
  final DateTime? expiresAt;

  const PremiumStatus({
    required this.isPremium,
    required this.plan,
    this.expiresAt,
  });

  static const free = PremiumStatus(isPremium: false, plan: 'free');
}

/// Singleton wrapper around RevenueCat SDK (v9).
///
/// Source of truth for subscription status once configured.
/// Falls back gracefully when no API key is set.
class PurchaseService {
  PurchaseService._();

  static bool _initialized = false;

  /// Whether the SDK was successfully initialized with a valid key.
  static bool get isConfigured => _initialized;

  // ─── Initialization ─────────────────────────────────────────────────

  /// Initialize RevenueCat. Call once in main.dart after Supabase init.
  /// No-op if [apiKey] is empty.
  static Future<void> init(String apiKey, {String? appUserId}) async {
    if (apiKey.isEmpty) return;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final config = PurchasesConfiguration(apiKey);
      if (appUserId != null) {
        config.appUserID = appUserId;
      }

      await Purchases.configure(config);
      _initialized = true;
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  // ─── User Identity ──────────────────────────────────────────────────

  /// Link RevenueCat user to your app's user ID (e.g. Supabase UUID).
  static Future<void> login(String userId) async {
    if (!_initialized) return;
    try {
      final result = await Purchases.logIn(userId);
      await _syncToSupabase(_statusFromCustomerInfo(result.customerInfo));
    } catch (e) {
      debugPrint('RevenueCat login error: $e');
    }
  }

  /// Clear RevenueCat user identity on sign-out.
  static Future<void> logout() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat logout error: $e');
    }
  }

  // ─── Entitlement Checks ─────────────────────────────────────────────

  /// Check whether the user has the active "premium" entitlement.
  static Future<bool> isPremium() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      debugPrint('RevenueCat isPremium error: $e');
      return false;
    }
  }

  /// Detailed premium status with the real plan and expiration date.
  /// Returns null when RevenueCat is unreachable — callers should fall
  /// back to the Supabase-cached subscription in that case.
  static Future<PremiumStatus?> getPremiumStatus() async {
    if (!_initialized) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      final status = _statusFromCustomerInfo(info);
      await _syncToSupabase(status);
      return status;
    } catch (e) {
      debugPrint('RevenueCat getPremiumStatus error: $e');
      return null;
    }
  }

  /// Derive premium status (plan + real expiry) from [CustomerInfo].
  static PremiumStatus _statusFromCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[_entitlementId];
    if (entitlement == null) return PremiumStatus.free;

    final expiresAt = DateTime.tryParse(entitlement.expirationDate ?? '');

    // Trial takes precedence so trials are displayed correctly.
    final String plan;
    if (entitlement.periodType == PeriodType.trial) {
      plan = 'trial';
    } else {
      final productId = entitlement.productIdentifier.toLowerCase();
      if (productId.contains('month')) {
        plan = 'monthly';
      } else if (productId.contains('year')) {
        plan = 'yearly';
      } else {
        plan = 'monthly'; // unknown product — display fallback only
      }
    }

    return PremiumStatus(isPremium: true, plan: plan, expiresAt: expiresAt);
  }

  /// Persist premium state to the Supabase `subscriptions` table so it
  /// stays a usable cache when RevenueCat is unreachable.
  ///
  /// Only premium states are written. Downgrades need no write: the
  /// stored `expires_at` is real, so the cached subscription flips to
  /// expired on its own at the right time.
  static Future<void> _syncToSupabase(PremiumStatus status) async {
    if (!status.isPremium) return;
    await DatabaseService.upsertSubscription(
      plan: status.plan,
      expiresAt: status.expiresAt,
    );
  }

  /// Get full customer info for detailed subscription status.
  static Future<CustomerInfo?> getCustomerInfo() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat getCustomerInfo error: $e');
      return null;
    }
  }

  /// Listen for real-time customer info changes (e.g. purchase from
  /// another device, subscription renewal/expiry).
  static void addCustomerInfoListener(
    void Function(CustomerInfo) listener,
  ) {
    if (!_initialized) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  // ─── Offerings & Purchases ──────────────────────────────────────────

  /// Fetch available offerings (monthly, yearly, lifetime packages).
  static Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('RevenueCat getOfferings error: $e');
      return null;
    }
  }

  /// Trigger a purchase for the given [package].
  /// Returns true if the user now has the "premium" entitlement.
  static Future<bool> purchase(Package package) async {
    if (!_initialized) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final status = _statusFromCustomerInfo(result.customerInfo);
      await _syncToSupabase(status);
      return status.isPremium;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — not an error
        return false;
      }
      debugPrint('RevenueCat purchase error: $errorCode');
      return false;
    } catch (e) {
      debugPrint('RevenueCat purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases.
  /// Returns true if the user now has the "premium" entitlement.
  static Future<bool> restorePurchases() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.restorePurchases();
      final status = _statusFromCustomerInfo(info);
      await _syncToSupabase(status);
      return status.isPremium;
    } catch (e) {
      debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }

  // ─── RevenueCat Paywall (purchases_ui_flutter) ──────────────────────

  /// Present the RevenueCat-configured paywall.
  /// Returns the [PaywallResult] indicating what happened.
  static Future<PaywallResult> presentPaywall() async {
    return RevenueCatUI.presentPaywall(displayCloseButton: true);
  }

  /// Present the paywall only if the user does NOT have "premium".
  /// Skips the paywall entirely if the entitlement is already active.
  static Future<PaywallResult> presentPaywallIfNeeded() async {
    return RevenueCatUI.presentPaywallIfNeeded(
      _entitlementId,
      displayCloseButton: true,
    );
  }

  // ─── Customer Center (purchases_ui_flutter) ─────────────────────────

  /// Present the RevenueCat Customer Center for subscription management.
  /// Handles cancellation, refunds, plan changes natively.
  static Future<void> presentCustomerCenter({
    void Function(CustomerInfo)? onRestoreCompleted,
  }) async {
    if (!_initialized) return;
    await RevenueCatUI.presentCustomerCenter(
      onRestoreCompleted: onRestoreCompleted,
    );
  }

  // ─── Management URL (fallback) ──────────────────────────────────────

  /// Get the App Store / Play Store management URL.
  static Future<String?> getManagementUrl() async {
    if (!_initialized) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.managementURL;
    } catch (e) {
      debugPrint('RevenueCat management URL error: $e');
      return null;
    }
  }
}
