import 'package:flutter/material.dart';

/// All shared app colors. Prefer these over inline [Color] literals.
class AppColors {
  AppColors._();

  /// Registered in [pubspec.yaml] under `assets/fonts/`.
  static const String fontFamily = 'Roboto';

  /////New Design///
  static const Color primaryColor = Color(0xFFB267FF);
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color premiumColor = Color(0xFFFD9149);

  // Home "Main Features" card gradients.
  static const LinearGradient featureVideoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD476FF), Color(0xFF4B3AFF)],
  );
  static const LinearGradient featureAudioGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D6EF1), Color(0xFF34EDC7)],
  );
  static const LinearGradient featureMessageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDB96A), Color(0xFFF2609E)],
  );

  // —— Neutrals ——
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  /// Same as [Colors.black87].
  static const Color black87 = Color(0xDD000000);

  // —— Text (black on light background, premultiplied alpha) ——
  static const Color textMuted72 = Color(0xB8000000);
  static const Color textMuted65 = Color(0xA6000000);
  static const Color textMuted55 = Color(0x8C000000);
  static const Color textMuted45 = Color(0x73000000);

  // —— Theme seed (Material [ColorScheme]) ——
  static const Color themeSeed = Color(0xFF6C63FF);

  // —— Brand / app bar gradient ——
  static const Color gradientAppBarStart = Color(0xFF7EC8F5);
  static const Color gradientAppBarMid = Color(0xFF5FAFE0);
  static const Color gradientAppBarEnd = Color(0xFF4A90C2);

  /// Pill “Call again” on fake audio call screen (muted steel blue).
  static const Color callAgainPillBlue = Color(0xFF5B8FD4);

  /// Incoming audio call — Decline / Accept.
  static const Color audioCallDecline = Color(0xFFEB5545);
  static const Color audioCallAccept = Color(0xFF67CE67);

  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientAppBarStart, gradientAppBarMid, gradientAppBarEnd],
  );

  /// Settings switches — ON track (#5FAFE0 → #4A90C2).
  static const LinearGradient settingsSwitchOnGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientAppBarMid, gradientAppBarEnd],
  );

  // —— Onboarding ——
  static const LinearGradient onboardingBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x2B5FAFE0), Color(0x474A90C2), Color(0x00FFFFFF)],
    stops: [0.0, 0.20, 0.99],
  );

  static const Color onboardingDotActive = Color(0xFF5FAFE0);
  static const Color onboardingDotInactive = Color(0x665FAFE0);
  static const Color onboardingNextButton = Color(0xFF5FAFE0);
  static const LinearGradient onboardingNextButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      gradientAppBarMid, // #5FAFE0
      gradientAppBarEnd, // #4A90C2
    ],
  );

  // —— Language screen ——
  /// Selected tile fill: `#7BBCE3` @ ~19% (#7BBCE330 → ARGB).
  static const Color languageCardSelectedFill = Color(0x307BBCE3);

  /// Border + selected radio ring/dot (solid `#7BBCE3`).
  static const Color languageSelectedAccent = Color(0xFF7BBCE3);

  static const Color languageCardBorderUnselected = Color(0xFFE8E8E8);
  static const Color languageRadioBorderUnselected = Color(0xFFC5C5C5);

  /// Skeleton / shimmer (aligned with home card blues).
  static const Color shimmerBase = Color(0xFFC9DCE8);
  static const Color shimmerHighlight = Color(0xFFF2F7FB);

  // —— Home screen cards ——
  /// Video card background: #4A90C24D (RRGGBBAA -> Flutter ARGB).
  static const Color homeVideoCardColor = Color(0x4D4A90C2);

  /// Audio card background: #EC48994D (RRGGBBAA -> Flutter ARGB).
  static const Color homeAudioCardColor = Color(0x4DEC4899);

  // —— Splash ——
  static const Color splashProgressTrack = Color(0xFFDFD4F3);
  static const Color splashTitleShadow = Color(0x33000000);
}
