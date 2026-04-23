import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/network_reachability.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/gradient_app_bar.dart';
import '../../../widgets/person_circle_tile.dart';
import '../controllers/persons_catalog_controller.dart';

class PersonsCatalogView extends GetView<PersonsCatalogController> {
  const PersonsCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: GradientAppBar(
        title: 'choose_category'.tr,
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            width: 22,
            height: 22,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.storage.isLoading.value &&
              controller.storage.persons.isEmpty) {
            return const ShimmerPersonGrid();
          }
          if (controller.storage.loadError.value != null &&
              controller.storage.persons.isEmpty) {
            return _ErrorState(
              message: controller.storage.loadError.value!,
              onRetry: controller.storage.loadPersons,
            );
          }
          final visible = controller.visiblePersons;
          if (visible.isEmpty) {
            final hasAny = controller.storage.persons.isNotEmpty;
            final msg = !controller.forVideoCall && hasAny
                ? 'No audio contacts here. Video-only people are listed under Fake Video Call.'
                : 'No people found in Storage (persons/).';
            return _ErrorState(
              message: msg,
              onRetry: controller.storage.loadPersons,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 1,
              crossAxisSpacing: 30,
              childAspectRatio: 0.80,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final person = visible[index];
              return PersonCircleTile(
                label: person.firstName,
                imageUrl: person.imageUrl,
                avatarSize: 72,
                maxLabelLines: 2,
                showAvatarBorder: false,
                useScallopedAvatarFrame: !controller.forVideoCall,
                needsNetworkForMedia: controller.forVideoCall
                    ? isRemoteMediaUrl(person.videoUrl)
                    : isRemoteMediaUrl(person.audioUrl),
                onTap: () => controller.onPersonTap(person),
              );
            },
          );
        }),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted55),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text('retry'.tr)),
          ],
        ),
      ),
    );
  }
}
