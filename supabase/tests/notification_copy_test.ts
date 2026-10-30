import {
  formatDailyPush,
  formatPushByTone,
} from "../functions/_shared/notification_copy.ts";

function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`expected ${JSON.stringify(expected)} but got ${JSON.stringify(actual)}`);
  }
}

Deno.test("bill name appears once, never loses the due time", () => {
  const notice = formatPushByTone("invoice", "Internet", "Internet vence amanhã", "normal");
  equal(notice.title, "Internet");
  equal(notice.body, "Vence amanhã");
});

Deno.test("tone is short and still respects user preference", () => {
  const original = "Fatura vence amanhã. R$ 260,40.";
  equal(
    formatPushByTone("invoice", "Cartão", original, "welcoming").body,
    "Olha só: " + original,
  );
  equal(
    formatPushByTone("invoice", "Cartão", original, "firm").body,
    "Atenção: " + original,
  );
  equal(
    formatPushByTone("invoice", "Cartão", original, "aggressive").body,
    "Porra: " + original,
  );
});

Deno.test("a pending daily review becomes one short actionable message", () => {
  const notice = formatDailyPush(
    "Sua revisão do Fôlego",
    "Confira os gastos de hoje e as próximas contas. 2 lançamento(s) esperando classificação.",
  );
  equal(notice.title, "Seu Fôlego hoje");
  equal(notice.body, "2 lançamentos para organizar.");
});

Deno.test("follow-up avoids long guilt-laden copy", () => {
  const notice = formatDailyPush(
    "Sua revisão precisa de você",
    "Você ainda não concluiu a revisão. Antes de gastar de novo, confira seu planejamento. 1 lançamento(s) esperando classificação.",
  );
  equal(notice.title, "Revisão pendente");
  equal(notice.body, "Atenção: 1 lançamento para organizar.");
});

Deno.test("unrecognized messages retain financial facts", () => {
  const notice = formatDailyPush("Resumo", "Saldo R$ 1.245,90 • 2 itens atrasados");
  equal(notice.title, "Resumo");
  equal(notice.body, "Saldo R$ 1.245,90 • 2 itens atrasados");
});

Deno.test("a weekly reminder keeps both commitments and budget info", () => {
  const notice = formatDailyPush(
    "Vamos cuidar do seu Fôlego?",
    "Dois minutinhos para cuidar do seu dinheiro. Revise as contas da semana e seu limite até receber.",
  );
  equal(notice.title, "Seu Fôlego hoje");
  equal(notice.body, "Olha só: Confira as contas da semana e seu limite.");
});
