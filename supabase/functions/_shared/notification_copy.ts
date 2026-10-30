// Copy layer only: does not change eligibility, financial data, dedupe or routes.
// Every notification keeps its factual names, amounts and timing.

export type ReminderStyle = "welcoming" | "normal" | "firm" | "aggressive";

function shortTonePrefix(style: string): string {
  switch (style) {
    case "welcoming": return "Olha só: ";
    case "firm": return "Atenção: ";
    case "aggressive": return "Porra: ";
    default: return "";
  }
}

function tidy(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

/** Daily summaries are composed by SQL with long habit reminders and tone
 * already applied. Reduce only recognized legacy phrases. Preserve the body
 * unchanged when an unknown future format might include financial facts. */
export function formatDailyPush(title: string, body: string): { title: string; body: string } {
  const followup = /Você ainda não concluiu a revisão\./i.test(body);
  const style = /porra|caralho/i.test(title + " " + body) ? "aggressive"
    : /Sua revisão precisa|Antes de gastar de novo/i.test(title + " " + body) ? "firm"
    : /Vamos cuidar|Dois minutinhos/i.test(title + " " + body) ? "welcoming"
    : "normal";
  const pending = body.match(/(\d+)\s+lançamento\(s\)\s+esperando classificação\./i);
  let core: string;
  if (pending) {
    const count = Number(pending[1]);
    core = count + (count === 1 ? " lançamento para organizar." : " lançamentos para organizar.");
  } else if (body.includes("Revise as contas da semana e seu limite até receber.")) {
    core = "Confira as contas da semana e seu limite.";
  } else if (body.includes("Conclua sua revisão, mesmo se não teve movimentações.")) {
    core = "Seu resumo está pronto. Quer conferir?";
  } else {
    // No lossy truncation: keep future or unknown factual message content.
    return { title: tidy(title), body: tidy(body) };
  }
  return {
    title: followup ? "Revisão pendente" : "Seu Fôlego hoje",
    body: shortTonePrefix(style) + core,
  };
}

/** Titles already identify the account, bill or merchant.
 * Removing an exact repetition makes the notification much easier to scan. */
export function formatPushByTone(
  kind: string,
  title: string,
  body: string,
  reminderStyle: string,
): { title: string; body: string } {
  if (kind === "dailySummary" || kind === "dailyFollowup") {
    return formatDailyPush(title, body);
  }
  const cleanTitle = tidy(title);
  let cleanBody = tidy(body);
  const repeated = cleanTitle && cleanBody.toLowerCase().startsWith(cleanTitle.toLowerCase() + " ");
  if (repeated) {
    const remainder = cleanBody.slice(cleanTitle.length + 1).trim();
    // Only remove repetition when the remainder is meaningful.
    if (remainder) cleanBody = remainder[0].toUpperCase() + remainder.slice(1);
  }
  return { title: cleanTitle, body: shortTonePrefix(reminderStyle) + cleanBody };
}
