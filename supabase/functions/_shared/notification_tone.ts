// A single outbound tone policy for every server-side financial push.
//
// The daily review / follow-up are already fully styled by
// get_daily_summary_push_candidates using the user's reminder_style. Do not
// decorate those twice. Other notification types are styled right before
// delivery and before persisting to notification_history.
export type ReminderStyle = "welcoming" | "normal" | "firm" | "aggressive";

export function formatPushByTone(
  kind: string,
  title: string,
  body: string,
  reminderStyle: string,
): { title: string; body: string } {
  if (kind === "dailySummary" || kind === "dailyFollowup") {
    return { title, body };
  }
  const prefix = reminderStyle === "welcoming"
    ? "Vamos cuidar disso com calma. "
    : reminderStyle === "firm"
    ? "Atenção: confira este aviso agora. "
    : reminderStyle === "aggressive"
    ? "Porra, presta atenção nisso: "
    : "";
  return { title, body: prefix + body };
}
