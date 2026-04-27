import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/network_reachability.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/person_circle_tile.dart';
import '../../home/widgets/vfc_celebrities_section.dart';
import '../controllers/persons_catalog_controller.dart';

class PersonsCatalogView extends GetView<PersonsCatalogController> {
  const PersonsCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    final isAudioCatalog = !controller.forVideoCall;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            matchTextDirection: true,
            width: 22,
            height: 22,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          isAudioCatalog ? 'persons_audio_catalog_title'.tr : 'choose_category'.tr,
          style: const TextStyle(
            fontFamily: 'Audiowide',
            fontSize: 24,
            color: AppColors.black,
            letterSpacing: 0.2,
          ),
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
                ? 'persons_no_audio_contacts'.tr
                : 'persons_no_people_found'.tr;
            return _ErrorState(
              message: msg,
              onRetry: controller.storage.loadPersons,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: isAudioCatalog ? 12 : 1,
              crossAxisSpacing: isAudioCatalog ? 12 : 30,
              childAspectRatio: isAudioCatalog ? 0.72 : 0.80,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final person = visible[index];
              if (isAudioCatalog) {
                return TrendingCelebrityCard(
                  name: person.firstName,
                  imageUrl: person.imageUrl,
                  gradient: kTrendingGradients[index % kTrendingGradients.length],
                  showOnlineDot: true,
                  showVideoBadge: index.isEven,
                  onTap: () => controller.onPersonTap(person),
                );
              }
              return PersonCircleTile(
                label: person.firstName,
                imageUrl: person.imageUrl,
                avatarSize: 72,
                maxLabelLines: 2,
                showAvatarBorder: true,
                useScallopedAvatarFrame: false,
                needsNetworkForMedia: isRemoteMediaUrl(person.videoUrl),
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

