import '../subscriptions/subscription_access.dart';

/// UI guidance only. Enforce usage limits server-side before any paid AI call.
class IntelligencePlan {
  const IntelligencePlan._();
  static const freeMonthlySimulations = 3;
  static const premiumMonthlyAiQuestions = 30;

  static bool maySimulate({
    required SubscriptionAccess access,
    required int simulationsThisMonth,
  }) {
    if (simulationsThisMonth < 0) return false;
    return access.hasPremium ||
        simulationsThisMonth < freeMonthlySimulations;
  }

  static bool mayAskAi({
    required SubscriptionAccess access,
    required int questionsThisMonth,
  }) {
    return access.hasPremium &&
        questionsThisMonth >= 0 &&
        questionsThisMonth < premiumMonthlyAiQuestions;
  }
}
