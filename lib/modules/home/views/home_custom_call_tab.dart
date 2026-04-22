import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/network_reachability.dart';
import '../../../core/services/persons_storage_service.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../../../widgets/person_circle_tile.dart';
import '../controllers/home_controller.dart';

/// User-created video callers (storage) + add entry point.
class HomeCustomCallTab extends GetView<HomeController> {
  const HomeCustomCallTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final svc = Get.find<PersonsStorageService>();
      final _ = svc.persons.length;
      final loading = svc.isLoading.value && svc.persons.isEmpty;
      final list = controller.customVideoPersons;

      if (loading) {
        return const Center(child: AppLoadingIndicator(size: 40));
      }

      if (list.isEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 56,
              color: AppColors.textMuted45,
            ),
            const SizedBox(height: 16),
            Text(
              'custom_call_empty_title'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'custom_call_empty_body'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted65,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 28),
            Center(
              child: FilledButton.icon(
                onPressed: controller.openAddVideoPerson,
                icon: const Icon(Icons.add_rounded),
                label: Text('custom_call_add'.tr),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gradientAppBarEnd,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.openAddVideoPerson,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('custom_call_add'.tr),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gradientAppBarEnd,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 20,
            children: [
              for (final person in list)
                SizedBox(
                  width: 88,
                  child: PersonCircleTile(
                    label: person.firstName,
                    imageUrl: person.imageUrl,
                    maxLabelLines: 2,
                    labelColor: AppColors.black,
                    needsNetworkForMedia:
                        isRemoteMediaUrl(person.videoUrl),
                    onTap: () => controller.openVideoCall(person),
                  ),
                ),
            ],
          ),
          if (svc.loadError.value != null) ...[
            const SizedBox(height: 16),
            Text(
              svc.loadError.value!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted65,
                  ),
            ),
            TextButton(
              onPressed: svc.loadPersons,
              child: Text('retry'.tr),
            ),
          ],
        ],
      );
    });
  }
}
