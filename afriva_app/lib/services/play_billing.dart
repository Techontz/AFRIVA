import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import 'commerce_service.dart';

/// What happened to a Google Play purchase, for the screen that started it.
enum PlayPurchaseOutcome { success, pending, cancelled, failed }

class PlayPurchaseEvent {
  const PlayPurchaseEvent(this.productId, this.outcome, [this.message]);
  final String productId;
  final PlayPurchaseOutcome outcome;
  final String? message;
}

/// Google Play Billing for the Play Store build.
///
/// Every Afriva product is a one-time, consumable product (VIP passes, episode
/// packs, coins). A purchase is only finished (consumed) after the Afriva API
/// has checked it with Google and activated the plan; anything left unfinished
/// (app closed, offline) is picked up again on the next launch, and Google
/// refunds purchases that are never finished within 3 days.
class PlayBilling {
  PlayBilling(this._commerce, {InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final CommerceService _commerce;
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _events = StreamController<PlayPurchaseEvent>.broadcast();
  final _products = <String, ProductDetails>{};

  /// Called after a verified purchase so the profile (VIP, coins) refreshes.
  void Function()? onEntitlementChanged;

  bool get enabled => AppConfig.isPlayStore;
  Stream<PlayPurchaseEvent> get events => _events.stream;

  /// Starts listening for purchases (including ones left from a previous session).
  void start() {
    if (!enabled || _sub != null) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    // Re-deliver purchases that were paid but not finished (they come back as "restored").
    _iap.restorePurchases().catchError((_) {});
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _events.close();
  }

  /// Google's localized details (price) for the given product ids.
  Future<Map<String, ProductDetails>> products(Set<String> ids) async {
    if (!enabled || ids.isEmpty || !await _iap.isAvailable()) return const {};
    final missing = ids.difference(_products.keys.toSet());
    if (missing.isNotEmpty) {
      final res = await _iap.queryProductDetails(missing);
      for (final p in res.productDetails) {
        _products[p.id] = p;
      }
    }
    return {for (final id in ids) if (_products[id] != null) id: _products[id]!};
  }

  /// Opens Google Play's payment sheet. The result arrives on [events].
  /// Not auto-consumed: it is consumed only after the API has activated it.
  Future<bool> buy(ProductDetails product) =>
      _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product), autoConsume: false);

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(PlayPurchaseEvent(p.productID, PlayPurchaseOutcome.pending));
        case PurchaseStatus.canceled:
          _events.add(PlayPurchaseEvent(p.productID, PlayPurchaseOutcome.cancelled));
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        case PurchaseStatus.error:
          _events.add(PlayPurchaseEvent(p.productID, PlayPurchaseOutcome.failed, p.error?.message));
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(p);
      }
    }
  }

  Future<void> _deliver(PurchaseDetails p) async {
    try {
      await _commerce.verifyPlayPurchase(
        productId: p.productID,
        purchaseToken: p.verificationData.serverVerificationData,
      );
    } on ApiException catch (e) {
      // Not signed in yet, or offline: leave it unfinished so it is retried later.
      // A purchase Google itself rejects stays unfinished and is refunded by Google.
      _events.add(PlayPurchaseEvent(p.productID, PlayPurchaseOutcome.failed, e.message));
      return;
    } catch (e) {
      _events.add(PlayPurchaseEvent(p.productID, PlayPurchaseOutcome.failed, errorMessage(e)));
      return;
    }
    // Verified and activated: consume it (this also acknowledges it) so it can be bought again.
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(p);
      } else if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    } catch (_) {
      // Already delivered; the server ignores a repeated token, so a later retry is harmless.
    }
    onEntitlementChanged?.call();
    _events.add(PlayPurchaseEvent(p.productID, PlayPurchaseOutcome.success));
  }
}
