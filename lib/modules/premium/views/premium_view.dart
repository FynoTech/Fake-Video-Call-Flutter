import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../../../app/theme/app_colors.dart';
import '../controllers/premium_controller.dart';
import '../models/subscription_period.dart';

class PremiumView extends GetView<PremiumController> {
  const PremiumView({super.key});

  static const String _heroAsset = 'assets/premium/pro_bg.png';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 360,
                  child: Image.asset(
                    _heroAsset,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => Image.asset(
                      _heroAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 4,
                  child: IconButton(
                    onPressed: Get.back,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
                child: Column(
                  children: [
                    Text(
                      'premium_title_top'.tr,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: AppColors.black,
                      ),
                    ),
                    Text(
                      'premium_title_bottom'.tr,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,

                        color: AppColors.gradientAppBarMid,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'premium_subtitle'.tr,
                      style: textTheme.titleMedium?.copyWith(
                        color: Color(0xff565656),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => _PlanCardsRow(
                        selected: controller.selectedPeriod.value,
                        isLoading: controller.isLoadingProducts.value,
                        onTap: controller.selectPeriod,
                        priceFor: controller.priceFor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: controller.purchase,
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: const Color(0xFF5097C9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Center(
                                    child: Text(
                                      controller.selectedPeriod.value ==
                                              SubscriptionPeriod.weekly
                                          ? 'premium_cta_trial'.tr
                                          : 'premium_cta_continue'.tr,
                                      textAlign: TextAlign.center,
                                      style: textTheme.headlineSmall?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4.0,
                                        bottom: 4,
                                        right: 4,
                                      ),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: const BoxDecoration(
                                          color: AppColors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const _AnimatedCtaArrow(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LegalLinks(
                      onTerms: controller.openTerms,
                      onPrivacy: controller.openPrivacy,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'premium_disclaimer'.tr,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted72,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCardsRow extends StatelessWidget {
  const _PlanCardsRow({
    required this.selected,
    required this.isLoading,
    required this.onTap,
    required this.priceFor,
  });

  final SubscriptionPeriod selected;
  final bool isLoading;
  final ValueChanged<SubscriptionPeriod> onTap;
  final String Function(SubscriptionPeriod) priceFor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PlanCard(
            period: SubscriptionPeriod.monthly,
            selected: selected == SubscriptionPeriod.monthly,
            isLoading: isLoading,
            price: priceFor(SubscriptionPeriod.monthly),
            onTap: () => onTap(SubscriptionPeriod.monthly),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlanCard(
            period: SubscriptionPeriod.weekly,
            selected: selected == SubscriptionPeriod.weekly,
            isLoading: isLoading,
            price: priceFor(SubscriptionPeriod.weekly),
            onTap: () => onTap(SubscriptionPeriod.weekly),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlanCard(
            period: SubscriptionPeriod.yearly,
            selected: selected == SubscriptionPeriod.yearly,
            isLoading: isLoading,
            price: priceFor(SubscriptionPeriod.yearly),
            onTap: () => onTap(SubscriptionPeriod.yearly),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.period,
    required this.selected,
    required this.isLoading,
    required this.price,
    required this.onTap,
  });

  final SubscriptionPeriod period;
  final bool selected;
  final bool isLoading;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelColor = selected ? AppColors.white : const Color(0xFF212933);
    final badgeTextColor = selected
        ? AppColors.gradientAppBarMid
        : AppColors.gradientAppBarEnd;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              height: 140,
              decoration: BoxDecoration(
                color: selected ? Color(0xff5097C9) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected ? Color(0xff5097C9) : const Color(0xFFF1F5F9),
                  width: selected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 10),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        period.badgeLabelKey.tr,
                        textAlign: TextAlign.center,
                        style: textTheme.labelMedium?.copyWith(
                          color: badgeTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: period == SubscriptionPeriod.weekly
                              ? 11
                              : 11,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    period.displayTitleKey.tr,
                    style: textTheme.headlineSmall?.copyWith(
                      color: labelColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  if (isLoading)
                    _PriceShimmer(selected: selected)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.white
                            : const Color(0xFFE2E5EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        price,
                        style: textTheme.titleMedium?.copyWith(
                          color: selected
                              ? AppColors.black
                              : const Color(0xFF9BA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        if (period == SubscriptionPeriod.yearly)
          Positioned(
            right: -6,
            top: -12,
            child: Transform.rotate(
              angle: 0.28,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFFF990B), Color(0xFFFDE277)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'premium_discount_badge'.tr,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriceShimmer extends StatelessWidget {
  const _PriceShimmer({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final base = selected ? const Color(0x80FFFFFF) : const Color(0xFFD9DEE8);
    final highlight = selected
        ? const Color(0xCCFFFFFF)
        : const Color(0xFFEFF3FA);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(width: 78, height: 30, color: Colors.white),
      ),
    );
  }
}

class _AnimatedCtaArrow extends StatefulWidget {
  const _AnimatedCtaArrow();

  @override
  State<_AnimatedCtaArrow> createState() => _AnimatedCtaArrowState();
}

class _AnimatedCtaArrowState extends State<_AnimatedCtaArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _offset = Tween<double>(
    begin: -1.5,
    end: 2.5,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (_, __) => Transform.translate(
        offset: Offset(_offset.value, 0),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Color(0xFF5097C9),
          size: 30,
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final linkStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.black,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.black,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTerms,
          child: Text('premium_terms'.tr, style: linkStyle),
        ),
        Text(
          '  |  ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted55),
        ),
        GestureDetector(
          onTap: onPrivacy,
          child: Text('premium_privacy'.tr, style: linkStyle),
        ),
      ],
    );
  }
}
