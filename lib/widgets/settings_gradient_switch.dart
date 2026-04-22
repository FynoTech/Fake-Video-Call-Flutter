import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';

/// iOS/Material-sized toggle; ON state uses [AppColors.settingsSwitchOnGradient].
class SettingsGradientSwitch extends StatelessWidget {
  const SettingsGradientSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _trackW = 44;
  static const double _trackH = 27;
  static const double _thumbD = 23;
  static const double _pad = 2;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        toggled: value,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: _trackW,
            height: _trackH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _trackW,
                  height: _trackH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_trackH / 2),
                    gradient:
                        value ? AppColors.settingsSwitchOnGradient : null,
                    color: value ? null : const Color(0xFFE9E9EA),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: value ? _trackW - _thumbD - _pad : _pad,
                  top: (_trackH - _thumbD) / 2,
                  child: Container(
                    width: _thumbD,
                    height: _thumbD,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
