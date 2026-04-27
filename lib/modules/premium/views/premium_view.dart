import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../controllers/premium_controller.dart';
import '../models/subscription_period.dart';

class PremiumView extends GetView<PremiumController> {
  const PremiumView({super.key});

  static const String _heroAsset = 'assets/premium/premium_bg_custom.png';
  static const String _crownAsset = 'assets/premium/premium_crown_custom.png';
  static const Color _textPrimary = Color(0xFFF7F7FF);
  static const Color _textSecondary = Color(0xFFE2E4F4);
  static const Color _textMuted = Color(0xFFD4D7EA);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= 380;
    return Scaffold(
      backgroundColor: const Color(0xFF050016),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _heroAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x26000000),
                  Color(0xFF050016),
                  Color(0xFF000000),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 4, compact ? 14 : 18, 14),
              child: Obx(
                () => Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                onTap: Get.back,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Image.asset(
                              _crownAsset,
                              width: 140,
                              height: 92,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: compact ? 14 : 20),
                            Text(
                              'premium_go_title'.tr,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: compact ? 24 : 31,
                                fontWeight: FontWeight.w700,
                                height: 0.95,
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Text(
                              'premium_go_subtitle'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: compact ? 12.5 : 14,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: compact ? 14 : 18),
                            _FeatureChecksGrid(compact: compact),
                            SizedBox(height: compact ? 16 : 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.diamond_rounded,
                                  color: Color(0xFF8FD7FF),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'premium_choose_plan'.tr,
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: compact ? 14 : 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            _PlanTile(
                              compact: compact,
                              period: SubscriptionPeriod.weekly,
                              selected:
                                  controller.selectedPeriod.value ==
                                  SubscriptionPeriod.weekly,
                              price: controller.priceFor(
                                SubscriptionPeriod.weekly,
                              ),
                              suffix: 'premium_suffix_week'.tr,
                              onTap: () => controller.selectPeriod(
                                SubscriptionPeriod.weekly,
                              ),
                            ),
                            SizedBox(height: compact ? 14 : 17),
                            _PlanTile(
                              compact: compact,
                              period: SubscriptionPeriod.monthly,
                              selected:
                                  controller.selectedPeriod.value ==
                                  SubscriptionPeriod.monthly,
                              price: controller.priceFor(
                                SubscriptionPeriod.monthly,
                              ),
                              suffix: 'premium_suffix_month'.tr,
                              badge: 'premium_badge_popular'.tr,
                              badgeColor: const Color(0xFFBC0303),
                              onTap: () => controller.selectPeriod(
                                SubscriptionPeriod.monthly,
                              ),
                            ),
                            SizedBox(height: compact ? 14 : 17),
                            _PlanTile(
                              compact: compact,
                              period: SubscriptionPeriod.yearly,
                              selected:
                                  controller.selectedPeriod.value ==
                                  SubscriptionPeriod.yearly,
                              price: controller.priceFor(
                                SubscriptionPeriod.yearly,
                              ),
                              suffix: 'premium_suffix_year'.tr,
                              badge: 'premium_badge_best_value'.tr,
                              badgeColor: const Color(0xFFF4B537),
                              onTap: () => controller.selectPeriod(
                                SubscriptionPeriod.yearly,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: controller.purchase,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB267FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          'premium_unlock_now'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    _PremiumFooterNote(compact: compact),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.compact,
    required this.period,
    required this.selected,
    required this.price,
    required this.suffix,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final bool compact;
  final SubscriptionPeriod period;
  final bool selected;
  final String price;
  final String suffix;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              height: compact ? 54 : 61,
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? const Color(0xFFBC8AFF) : Color(0xffA7A7A7),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _RadioMark(selected: selected),
                  SizedBox(width: compact ? 8 : 14),
                  Expanded(
                    child: Text(
                      '${period.displayTitleKey.tr} ${'premium_plan_word'.tr}',
                      style: TextStyle(
                        color: PremiumView._textPrimary,
                        fontSize: compact ? 12.5 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? 124 : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$price $suffix',
                        style: TextStyle(
                          color: PremiumView._textSecondary,
                          fontSize: compact ? 12 : 18,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFFE7332B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: badgeColor == const Color(0xFFF8C53A)
                        ? AppColors.black
                        : AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureChecksGrid extends StatelessWidget {
  const _FeatureChecksGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: compact ? 0 : 35),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _FeatureCheckItem(text: 'premium_feature_audio'.tr, compact: compact),
              ),

              Flexible(
                child: _FeatureCheckItem(text: 'premium_feature_video'.tr, compact: compact),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Row(
          children: [
            Expanded(
              child: _FeatureCheckItem(text: 'premium_feature_chat'.tr, compact: compact),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: _FeatureCheckItem(
                text: 'premium_feature_characters'.tr,
                compact: compact,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        Row(
          children: [
            Expanded(
              child: _FeatureCheckItem(text: 'premium_feature_ads_free'.tr, compact: compact),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: _FeatureCheckItem(
                text: 'premium_feature_unlimited_pranks'.tr,
                compact: compact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureCheckItem extends StatelessWidget {
  const _FeatureCheckItem({required this.text, required this.compact});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 21 : 25,
          height: compact ? 21 : 25,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: Color(0xFF171824),
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PremiumView._textPrimary,
              fontSize: compact ? 12 : 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumFooterNote extends StatelessWidget {
  const _PremiumFooterNote({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'premium_no_commitment'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: PremiumView._textPrimary,
            fontSize: compact ? 13.5 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? const Color(0xFFBB86FF)
              : Colors.white.withValues(alpha: 0.75),
          width: 1,
        ),
      ),
      child: selected
          ? Padding(
              padding: const EdgeInsets.all(2.0),
              child: const Center(
                child: CircleAvatar(
                  radius: 7,
                  backgroundColor: Color(0xFFBB86FF),
                ),
              ),
            )
          : null,
    );
  }
}
