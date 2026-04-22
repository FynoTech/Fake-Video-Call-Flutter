import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_colors.dart';

/// App-wide app bar with the brand linear gradient and light (white) content.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      color: AppColors.white,
      fontWeight: FontWeight.w700,
      fontSize: 18,
    );

    return AppBar(
      leading: leading,
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title:
          titleWidget ??
          (title != null ? Text(title!, style: titleStyle) : null),
      centerTitle: centerTitle,
      actions: actions,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.transparent,
      surfaceTintColor: AppColors.transparent,
      foregroundColor: AppColors.white,
      iconTheme: const IconThemeData(color: AppColors.white),
      actionsIconTheme: const IconThemeData(color: AppColors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
      ),
    );
  }
}
