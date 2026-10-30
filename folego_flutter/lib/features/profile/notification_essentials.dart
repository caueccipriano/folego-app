import '../../core/notifications/notification_models.dart';

/// Explicit opt-in to a calmer notification experience. Saved due-date,
/// overdue, budget, card and large-expense alerts remain untouched.
bool essentialNotificationsOnly(NotificationPreferences prefs) =>
    !prefs.dailySummaryEnabled &&
    !prefs.commitmentEnabled &&
    !prefs.weeklyReviewEnabled &&
    !prefs.transactionActivityEnabled;

/// Never changes another kind of notification or the master switch.
/// Calling it does not save anything; the UI must request user action.
NotificationPreferences reduceNotificationNoise(NotificationPreferences prefs) =>
    prefs.copyWith(
      dailySummaryEnabled: false,
      commitmentEnabled: false,
      weeklyReviewEnabled: false,
      transactionActivityEnabled: false,
    );
