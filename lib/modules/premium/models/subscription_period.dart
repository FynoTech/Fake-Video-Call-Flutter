/// Billing cadence shown on the Premium screen.
enum SubscriptionPeriod {
  weekly,
  monthly,
  yearly,
}

extension SubscriptionPeriodX on SubscriptionPeriod {
  String get displayTitleKey => switch (this) {
        SubscriptionPeriod.monthly => 'premium_plan_monthly',
        SubscriptionPeriod.weekly => 'premium_plan_weekly',
        SubscriptionPeriod.yearly => 'premium_plan_yearly',
      };

  String get productId => switch (this) {
        SubscriptionPeriod.monthly => 'monthly_subscription',
        SubscriptionPeriod.weekly => 'weekly_subscription',
        SubscriptionPeriod.yearly => 'yearly_subscription',
      };

  String get badgeLabelKey => switch (this) {
        SubscriptionPeriod.monthly => 'premium_badge_popular',
        SubscriptionPeriod.weekly => 'premium_badge_trial',
        SubscriptionPeriod.yearly => 'premium_badge_best_value',
      };

  String get fallbackPrice => switch (this) {
        SubscriptionPeriod.monthly => '\$19.99',
        SubscriptionPeriod.weekly => '\$19.99',
        SubscriptionPeriod.yearly => '\$39.99',
      };
}
