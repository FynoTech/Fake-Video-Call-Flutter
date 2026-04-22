import 'dart:async';

import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'storage_service.dart';

/// Central source of truth for premium entitlement.
///
/// This is client-side entitlement only. For stricter validation, add backend
/// receipt verification and sync the result here.
class SubscriptionService extends GetxService {
  static const Set<String> subscriptionProductIds = {
    'monthly_subscription',
    'weekly_subscription',
    'yearly_subscription',
  };

  final RxBool isPremium = false.obs;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  late final StorageService _storage;

  bool _storeAvailable = false;

  Future<SubscriptionService> init() async {
    _storage = Get.find<StorageService>();
    isPremium.value = _storage.isPremiumUnlocked;
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {},
    );
    _storeAvailable = await _iap.isAvailable();
    if (_storeAvailable) {
      unawaited(refreshEntitlement());
    }
    return this;
  }

  Future<void> refreshEntitlement() async {
    if (!_storeAvailable) return;
    try {
      if (!GetPlatform.isAndroid) {
        await _iap.restorePurchases();
        return;
      }

      final androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();
      final hasActive = response.pastPurchases.any(
        (p) => subscriptionProductIds.contains(p.productID),
      );
      await _setPremium(hasActive);
    } catch (_) {}
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    var grantPremium = isPremium.value;
    var hasRelevantUpdate = false;

    for (final purchase in updates) {
      if (!subscriptionProductIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }
      hasRelevantUpdate = true;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          grantPremium = true;
          break;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
        case PurchaseStatus.pending:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    if (hasRelevantUpdate) {
      await _setPremium(grantPremium);
      // Reconcile against Play owned purchases for Android.
      await refreshEntitlement();
    }
  }

  Future<void> _setPremium(bool value) async {
    if (isPremium.value == value) return;
    isPremium.value = value;
    await _storage.setPremiumUnlocked(value);
  }

  @override
  void onClose() {
    _purchaseSub?.cancel();
    super.onClose();
  }
}
