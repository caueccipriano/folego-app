class OnboardingState {
  const OnboardingState({
    required this.accountCount,
    required this.hasAccount,
    required this.hasConfirmedIncome,
    required this.recurringExpenseCount,
    required this.hasCard,
    required this.budgetConfigured,
    required this.reserveConfigured,
    required this.folegoReady,
    required this.onboardingCompleted,
  });

  final int accountCount;
  final bool hasAccount;
  final bool hasConfirmedIncome;
  final int recurringExpenseCount;
  final bool hasCard;
  final bool budgetConfigured;
  final bool reserveConfigured;
  final bool folegoReady;
  final bool onboardingCompleted;

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    return OnboardingState(
      accountCount: (json['account_count'] as num?)?.toInt() ?? 0,
      hasAccount: json['has_account'] as bool? ?? false,
      hasConfirmedIncome: json['has_confirmed_income'] as bool? ?? false,
      recurringExpenseCount:
          (json['recurring_expense_count'] as num?)?.toInt() ?? 0,
      hasCard: json['has_card'] as bool? ?? false,
      budgetConfigured: json['budget_configured'] as bool? ?? false,
      reserveConfigured: json['reserve_configured'] as bool? ?? false,
      folegoReady: json['folego_ready'] as bool? ?? false,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    );
  }
}
