import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Entitlement identifier configured in RevenueCat dashboard.
const _entitlementId = 'premium';

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
      await Purchases.logIn(userId);
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
      return result.customerInfo.entitlements.active
          .containsKey(_entitlementId);
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
      return info.entitlements.active.containsKey(_entitlementId);
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
