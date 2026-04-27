import 'dart:async';

import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/subscription_service.dart';
import '../models/subscription_period.dart';

class PremiumController extends GetxController {
  final selectedPeriod = SubscriptionPeriod.weekly.obs;
  final isLoadingProducts = true.obs;
  final availableProducts = <SubscriptionPeriod, ProductDetails>{}.obs;

  final InAppPurchase _iap = InAppPurchase.instance;
  SubscriptionService get _subscription => Get.find<SubscriptionService>();

  void selectPeriod(SubscriptionPeriod period) {
    selectedPeriod.value = period;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_subscription.refreshEntitlement());
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    isLoadingProducts.value = true;
    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      isLoadingProducts.value = false;
      return;
    }

    final ids = SubscriptionPeriod.values.map((e) => e.productId).toSet();
    final response = await _iap.queryProductDetails(ids);
    if (response.productDetails.isNotEmpty) {
      final map = <SubscriptionPeriod, ProductDetails>{};
      for (final period in SubscriptionPeriod.values) {
        final idx = response.productDetails.indexWhere(
          (p) => p.id == period.productId,
        );
        if (idx != -1) {
          map[period] = response.productDetails[idx];
        }
      }
      availableProducts.assignAll(map);
    }
    isLoadingProducts.value = false;
  }

  String priceFor(SubscriptionPeriod period) {
    final product = availableProducts[period];
    if (product != null) return product.price;
    return period.fallbackPrice;
  }

  Future<void> purchase() async {
    if (_subscription.isPremium.value) {
      Get.back<void>();
      return;
    }
    final product = availableProducts[selectedPeriod.value];
    if (product == null) {
      Get.snackbar(
        'Subscription',
        'Subscription details are still loading. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void openTerms() {
    Get.snackbar('Terms', 'Open your Terms of Use URL here.',
        snackPosition: SnackPosition.BOTTOM);
  }

  void openPrivacy() {
    Get.snackbar('Privacy', 'Open your Privacy Policy URL here.',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      await _subscription.refreshEntitlement();
      Get.snackbar(
        'Restore',
        'Restore request sent successfully.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Restore',
        'Unable to restore purchases right now.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
