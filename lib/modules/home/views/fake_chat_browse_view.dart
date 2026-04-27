import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../controllers/home_controller.dart';
import '../widgets/vfc_celebrities_section.dart';
import 'fake_chat_view.dart';

/// Browse celebrities for fake chat flow.
class FakeChatBrowseView extends StatefulWidget {
  const FakeChatBrowseView({super.key});

  @override
  State<FakeChatBrowseView> createState() => _FakeChatBrowseViewState();
}

class _FakeChatBrowseViewState extends State<FakeChatBrowseView> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final c = Get.find<HomeController>();
    final len = c.vfcCatalog.value?.categories.length ?? 0;
    _index = len <= 0 ? 0 : c.vfcSelectedCategoryIndex.value.clamp(0, len - 1);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: Row(
          children: [
            _BackButton(onTap: () => Get.back()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'fake_chat_title'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Audiowide',
                  fontSize: 24,
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final catalog = controller.vfcCatalog.value;
          if (catalog == null) {
            return const Center(child: AppLoadingIndicator(size: 40));
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: VfcCelebritiesSection(
              catalog: catalog,
              selectedCategoryIndex: _index,
              onCategoryChanged: (i) {
                setState(() => _index = i);
                controller.selectVfcCategory(i);
              },
              onCelebrityTap: (person, {forceWatchAdGate = false}) {
                Get.to(() => FakeChatView(person: person));
              },
              extraPersonsForSelected: catalog.categories.isEmpty
                  ? const []
                  : controller.customPersonsForCategory(
                      catalog.categories[
                              _index.clamp(0, catalog.categories.length - 1)]
                          .id,
                    ),
              expandGrid: true,
              avatarSize: 72,
            ),
          );
        }),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 20,
      icon: SvgPicture.asset(
        'assets/setting/ic_back.svg',
        matchTextDirection: true,
        width: 24,
        height: 24,
      ),
    );
  }
}
