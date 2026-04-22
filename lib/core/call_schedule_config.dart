/// Seconds for Settings → Call schedule (must match [callScheduleOptions] in
/// [SettingsController], excluding Off = 0).
const Set<int> kForegroundCallScheduleSeconds = {15, 25, 35, 45, 60};

/// Maps stored seconds to a valid choice; unknown legacy values become 0 (Off).
int normalizeForegroundCallScheduleSeconds(int stored) {
  if (stored <= 0) return 0;
  return kForegroundCallScheduleSeconds.contains(stored) ? stored : 0;
}
