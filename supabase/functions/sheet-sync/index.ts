import { createClient } from "npm:@supabase/supabase-js@2.116.0";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

const SHEET_CATEGORY_BY_SYSTEM_KEY: Record<string, string> = {
  "expense.food": "Alimentação",
  "expense.food.cafe": "Alimentação",
  "expense.food.delivery": "Delivery",
  "expense.food.restaurant": "Restaurantes",
  "expense.food.groceries": "Supermercado",
  "expense.food.bars": "Alimentação",
  "expense.subscriptions": "Assinaturas",
  "expense.beauty": "Beleza",
  "expense.beauty.hair": "Beleza",
  "expense.beauty.cosmetics": "Beleza",
  "expense.beauty.personal": "Beleza",
  "expense.beauty.aesthetics": "Beleza",
  "expense.beauty.laundry": "Beleza",
  "expense.shopping": "Compras online",
  "expense.shopping.accessories": "Vestuário",
  "expense.shopping.shoes": "Calçados",
  "expense.shopping.home": "Casa/Decoração",
  "expense.shopping.online": "Compras online",
  "expense.shopping.electronics": "Eletrônicos",
  "expense.shopping.marketplace": "Mercado Livre",
  "expense.shopping.clothes": "Vestuário",
  "expense.household": "Moradia",
  "expense.household.water": "Água",
  "expense.household.energy": "Energia",
  "expense.household.gas": "Gás",
  "expense.household.internet": "Internet/Telefone",
  "expense.household.phone": "Internet/Telefone",
  "expense.debt": "Empréstimos",
  "expense.debt.loans": "Empréstimos",
  "expense.debt.agreements": "Renegociação",
  "expense.debt.installments": "Crediário",
  "expense.education": "Educação",
  "expense.education.school": "Educação",
  "expense.finance": "Impostos/Taxas",
  "expense.finance.taxes": "Impostos/Taxas",
  "expense.finance.iof_fees": "Impostos/Taxas",
  "expense.finance.interest": "Juros",
  "expense.finance.bank_fees": "Tarifas bancárias",
  "expense.leisure": "Lazer",
  "expense.housing": "Moradia",
  "expense.housing.condo": "Condomínio",
  "expense.housing.furniture": "Casa/Decoração",
  "expense.other": "Outros",
  "expense.other.other": "Outros",
  "expense.pets": "Pets",
  "expense.gifts": "Presentes",
  "expense.gifts.presents": "Presentes",
  "expense.health": "Saúde",
  "expense.health.pharmacy": "Farmácia",
  "expense.health.supplements": "Suplementos",
  "expense.health.therapy": "Saúde",
  "expense.insurance": "Seguros",
  "expense.transport": "Transporte",
  "expense.transport.fuel": "Gasolina",
  "expense.transport.parking_toll": "Estacionamento/Pedágio",
  "expense.transport.vehicle_tax": "IPVA/Licenciamento",
  "expense.transport.maintenance": "Manutenção do carro",
  "expense.travel": "Viagens",
  "income.salary": "Salário",
  "income.salary_advance": "Salário",
  "income.freelance": "Outros",
  "income.commissions": "Outros",
  "income.bonus": "Outros",
  "income.sale": "Outros",
  "income.investment_returns": "Rendimentos",
  "income.gift": "Outros",
  "income.reimbursement": "Reembolso",
  "income.other": "Outros",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function norm(value: unknown): string {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function parseAmount(value: unknown): number {
  if (typeof value === "number") return Math.abs(value);
  let raw = String(value ?? "").replace(/R\$/gi, "").replace(/\s/g, "");
  if (raw.includes(",")) raw = raw.replace(/\./g, "").replace(",", ".");
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? Math.abs(parsed) : 0;
}

function parseInstallments(row: Record<string, unknown>): number {
  const direct = Number(row.installments_count ?? row.numero_parcelas ?? 0);
  if (Number.isInteger(direct) && direct > 0 && direct <= 120) return direct;
  const parcel = String(row.installment ?? row.parcela ?? "");
  const fraction = parcel.match(/\b\d{1,3}\s*\/\s*(\d{1,3})\b/);
  if (fraction) return Math.max(1, Math.min(120, Number(fraction[1])));
  const desc = String(row.description ?? row.descricao ?? "");
  const x = desc.match(/\b(\d{1,3})\s*[xX]\b/);
  return x ? Math.max(1, Math.min(120, Number(x[1]))) : 1;
}

function toIso(value: unknown): string {
  const raw = String(value ?? "").trim();
  if (!raw) throw new Error("sheet_date_missing");
  const br = raw.match(/^([0-9]{1,2})[/]([0-9]{1,2})[/]([0-9]{4})(?:[ T]+([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))?)?$/);
  let d: Date;
  if (br) {
    const day = Number(br[1]), month = Number(br[2]), year = Number(br[3]);
    const check = new Date(Date.UTC(year, month - 1, day));
    if (check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1 || check.getUTCDate() !== day) {
      throw new Error("sheet_date_invalid");
    }
    const pad = (n: number) => String(n).padStart(2, "0");
    const h = Number(br[4] ?? 0), m = Number(br[5] ?? 0), s = Number(br[6] ?? 0);
    if (h > 23 || m > 59 || s > 59) throw new Error("sheet_time_invalid");
    d = new Date(year + "-" + pad(month) + "-" + pad(day) + "T" + pad(h) + ":" + pad(m) + ":" + pad(s) + "-03:00");
  } else {
    d = new Date(raw);
  }
  if (Number.isNaN(d.getTime())) throw new Error("sheet_date_invalid");
  return d.toISOString();
}

function dateOnly(iso: string): string {
  return iso.slice(0, 10);
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

type Category = {
  id: string;
  name: string;
  kind: string;
  parent_id: string | null;
  system_key: string | null;
  category_role: string;
  is_selectable: boolean;
};
type Account = { id: string; name: string; institution: string | null; type: string };
type Card = { id: string; name: string; issuer: string | null; last_four: string | null };
type Context = {
  categories: Category[];
  categoriesById: Map<string, Category>;
  accounts: Account[];
  accountsById: Map<string, Account>;
  cards: Card[];
  cardsById: Map<string, Card>;
};

function categoryPath(category: Category, ctx: Context): string {
  const parent = category.parent_id ? ctx.categoriesById.get(category.parent_id) : null;
  return parent ? `${parent.name} > ${category.name}` : category.name;
}

function sheetCategory(category: Category | null): string {
  if (!category) return "A classificar";
  if (category.system_key === "special.unclassified") return "A classificar";
  if (category.system_key && SHEET_CATEGORY_BY_SYSTEM_KEY[category.system_key]) {
    return SHEET_CATEGORY_BY_SYSTEM_KEY[category.system_key];
  }
  if (category.system_key?.startsWith("income.")) return "Outros";
  return category.name;
}

function resolveAccount(raw: unknown, ctx: Context): Account | null {
  const label = norm(raw);
  if (!label) return null;
  return ctx.accounts.find((a) => norm(a.name) === label)
    ?? ctx.accounts.find((a) => norm(a.institution) === label)
    ?? null;
}

function resolveCard(raw: unknown, description: unknown, ctx: Context): Card | null {
  const candidates = [norm(raw), norm(description)].filter(Boolean);
  for (const text of candidates) {
    for (const card of ctx.cards) {
      // Do not treat a bank account name as a credit card solely because the issuer matches.
      const names = [norm(card.name), norm(card.last_four)].filter(Boolean);
      if (names.some((n) => text === n || text.includes(n))) return card;
      if (card.name === "AMEX Gold" && (text.includes("amex") || text.includes("bradesco cartoes"))) return card;
      if (card.name === "Porto" && (text.includes("porto") || text.includes("0115"))) return card;
    }
  }
  return null;
}

function inferTransferTarget(description: unknown, from: Account | null, ctx: Context): Account | null {
  const text = norm(description);
  return ctx.accounts.find((a) => a.id !== from?.id && text.includes(norm(a.name))) ?? null;
}

async function loadContext(supabase: any, spaceId: string): Promise<Context> {
  const [catRes, accRes, cardRes] = await Promise.all([
    supabase.from("categories")
      .select("id,name,kind,parent_id,system_key,category_role,is_selectable")
      .eq("space_id", spaceId).eq("active", true),
    supabase.from("accounts")
      .select("id,name,institution,type")
      .eq("space_id", spaceId).eq("active", true),
    supabase.from("credit_cards")
      .select("id,name,issuer,last_four")
      .eq("space_id", spaceId).eq("active", true),
  ]);
  if (catRes.error) throw catRes.error;
  if (accRes.error) throw accRes.error;
  if (cardRes.error) throw cardRes.error;
  const categories = (catRes.data ?? []) as Category[];
  const accounts = (accRes.data ?? []) as Account[];
  const cards = (cardRes.data ?? []) as Card[];
  return {
    categories,
    categoriesById: new Map(categories.map((c) => [c.id, c])),
    accounts,
    accountsById: new Map(accounts.map((a) => [a.id, a])),
    cards,
    cardsById: new Map(cards.map((c) => [c.id, c])),
  };
}

async function findExistingEvent(supabase: any, spaceId: string, rawId: string) {
  if (rawId.startsWith("event:")) {
    const id = rawId.slice(6);
    const { data } = await supabase.from("financial_events")
      .select("*").eq("space_id", spaceId).eq("id", id).maybeSingle();
    return data ?? null;
  }
  const externalId = rawId.startsWith("sheet:") ? rawId : `sheet:${rawId}`;
  const { data } = await supabase.from("financial_events")
    .select("*").eq("space_id", spaceId).eq("external_id", externalId).maybeSingle();
  return data ?? null;
}

async function safelyUpdateExisting(supabase: any, existing: any, row: Record<string, unknown>) {
  const incomingAmount = parseAmount(row.amount ?? row.valor);
  if (incomingAmount > 0 && Math.abs(Number(existing.amount) - incomingAmount) > 0.005) {
    return {
      status: "conflict_amount",
      event_id: existing.id,
      current_amount: Number(existing.amount),
      incoming_amount: incomingAmount,
    };
  }

  // A planilha pode corrigir a descrição, mas NUNCA a categoria econômica.
  // A classificação pertence ao usuário dentro do Fôlego.
  const description = String(row.description ?? row.descricao ?? existing.description).trim() || existing.description;
  const { error } = await supabase.from("financial_events")
    .update({ description, updated_at: new Date().toISOString() })
    .eq("id", existing.id).eq("space_id", existing.space_id);
  if (error) throw error;

  if (existing.event_type === "card_purchase") {
    const { error: purchaseError } = await supabase.from("card_purchases")
      .update({ description, updated_at: new Date().toISOString() })
      .eq("event_id", existing.id).eq("space_id", existing.space_id);
    if (purchaseError) throw purchaseError;
  }
  return { status: "updated", event_id: existing.id };
}

async function markNeedsClassification(
  supabase: any,
  spaceId: string,
  externalId: string,
  sheetCategoryOriginal: unknown,
) {
  const { data: event, error: readError } = await supabase.from("financial_events")
    .select("id,metadata")
    .eq("space_id", spaceId).eq("external_id", externalId).maybeSingle();
  if (readError) throw readError;
  if (!event) return;
  const metadata = {
    ...(event.metadata ?? {}),
    sheet_linked: true,
    needs_classification: true,
    sheet_category_original: String(sheetCategoryOriginal ?? "").trim() || null,
  };
  const { error } = await supabase.from("financial_events")
    .update({ metadata, updated_at: new Date().toISOString() })
    .eq("id", event.id);
  if (error) throw error;
}

async function pushRow(supabase: any, spaceId: string, row: Record<string, unknown>, ctx: Context) {
  const rawId = String(row.id ?? row.external_id ?? row.ID ?? "").trim();
  if (!rawId) return { status: "error", error: "missing_id" };

  const status = norm(row.status);
  if (["ignorar", "cancelada", "cancelado"].includes(status)) {
    return { id: rawId, status: "ignored_status" };
  }
  if (["sim", "duplicado"].includes(norm(row.possible_duplicate ?? row.possivel_duplicado))) {
    return { id: rawId, status: "ignored_duplicate" };
  }

  // Ajustes técnicos de conciliação pertencem ao caixa/auditoria local e não
  // podem virar despesa ou compra de cartão no Fôlego.
  const preliminaryType = norm(row.type ?? row.tipo);
  const preliminaryCategory = norm(row.category ?? row.categoria);
  const preliminaryDescription = norm(row.description ?? row.descricao);
  if (
    ["ajuste", "adjustment", "ajuste manual"].includes(preliminaryType) &&
    (
      preliminaryCategory.includes("conciliacao") ||
      preliminaryDescription.includes("conciliacao")
    )
  ) {
    return { id: rawId, status: "ignored_status", reason: "technical_adjustment" };
  }

  const existing = await findExistingEvent(supabase, spaceId, rawId);
  if (existing) {
    if (existing.status === "ignored" || existing.metadata?.duplicate_of) {
      return { id: rawId, status: "ignored_duplicate", event_id: existing.id };
    }
    return { id: rawId, ...(await safelyUpdateExisting(supabase, existing, row)) };
  }

  const type = norm(row.type ?? row.tipo);
  const description = String(row.description ?? row.descricao ?? "").trim();
  const amount = parseAmount(row.amount ?? row.valor);
  const occurredAt = toIso(row.occurred_at ?? row.data_hora ?? row.dataHora ?? row.date);
  const externalId = rawId.startsWith("sheet:") ? rawId : `sheet:${rawId}`;
  if (!description || amount <= 0) {
    return { id: rawId, status: "error", error: "invalid_description_or_amount" };
  }

  const accountLabel = row.account_card ?? row.conta_cartao ?? row.contaCartao ?? row.account ?? row.conta;
  const account = resolveAccount(accountLabel, ctx)
    ?? (norm(row.source ?? row.origem) === "santander" ? resolveAccount("Santander", ctx) : null);
  const card = resolveCard(accountLabel ?? row.card_name ?? row.cartao, description, ctx);
  const originalCategory = row.category ?? row.categoria;

  // Only manual sheet adjustments are compared with existing bank reconciliations.
  // Matching requires the same local day, amount, description, event type, AND cash account.
  if (account && norm(row.source ?? row.origem) === "ajuste manual") {
    const economicType = (type === "receita" || type === "income")
      ? (account.type === "benefit" ? "benefit_credit" : "income")
      : ((type === "despesa" || type === "expense")
        ? (account.type === "benefit" ? "benefit_expense" : "expense") : null);
    if (economicType) {
      const localDate = new Date(new Date(occurredAt).getTime() - 3 * 3600000).toISOString().slice(0, 10);
      const start = localDate + "T03:00:00.000Z";
      const end = new Date(Date.parse(start) + 86400000).toISOString();
      const { data: reconciled, error: reconError } = await supabase.from("financial_events")
        .select("id,description").eq("space_id", spaceId)
        .eq("source", "reconciliation").eq("status", "confirmed")
        .eq("event_type", economicType).eq("amount", amount)
        .gte("occurred_at", start).lt("occurred_at", end).limit(15);
      if (reconError) throw reconError;
      for (const candidate of reconciled ?? []) {
        if (norm(candidate.description) !== norm(description)) continue;
        const { data: sameAccount, error: impactError } = await supabase.from("financial_impacts")
          .select("id").eq("event_id", candidate.id)
          .eq("dimension", account.type === "benefit" ? "benefit" : "cash")
          .eq("account_id", account.id).limit(1);
        if (impactError) throw impactError;
        if (sameAccount?.length) {
          return { id: rawId, status: "ignored_duplicate", duplicate_of: candidate.id };
        }
      }
    }
  }

  if (type === "receita" || type === "income") {
    if (!account) return { id: rawId, status: "error", error: "income_account_not_found" };
    let data: any;
    let error: any;
    if (account.type === "benefit") {
      ({ data, error } = await supabase.rpc("sheet_sync_register_benefit", {
        p_space_id: spaceId,
        p_account_id: account.id,
        p_amount: amount,
        p_description: description,
        p_is_credit: true,
        p_category_id: null,
        p_occurred_at: occurredAt,
        p_external_id: externalId,
      }));
    } else {
      ({ data, error } = await supabase.rpc("sheet_sync_register_income", {
        p_space_id: spaceId,
        p_account_id: account.id,
        p_amount: amount,
        p_description: description,
        p_category_id: null,
        p_occurred_at: occurredAt,
        p_competence_date: dateOnly(occurredAt),
        p_external_id: externalId,
      }));
    }
    if (error) throw error;
    await markNeedsClassification(supabase, spaceId, externalId, originalCategory);
    return { id: rawId, status: "inserted", event_id: data };
  }

  if (type === "transferencia" || type === "transfer") {
    const categoryText = norm(originalCategory);
    if (categoryText.includes("pagamento de cartao") || norm(description).includes("fatura")) {
      if (!account) return { id: rawId, status: "error", error: "payment_account_not_found" };
      const paymentCard = resolveCard(row.card_name ?? row.vinculo_cartao ?? row.vinculoCartao, description, ctx) ?? card;
      if (!paymentCard) return { id: rawId, status: "error", error: "payment_card_not_found" };
      const { data: invoices, error: invoiceError } = await supabase.from("card_invoices")
        .select("id,due_date,status")
        .eq("space_id", spaceId).eq("card_id", paymentCard.id)
        .in("status", ["open", "partially_paid"])
        .order("due_date", { ascending: true }).limit(1);
      if (invoiceError) throw invoiceError;
      if (!invoices?.length) return { id: rawId, status: "needs_review", error: "open_invoice_not_found" };
      const { data, error } = await supabase.rpc("sheet_sync_pay_card_invoice", {
        p_space_id: spaceId,
        p_invoice_id: invoices[0].id,
        p_account_id: account.id,
        p_amount: amount,
        p_payment_type: "payment",
        p_paid_at: occurredAt,
        p_external_id: externalId,
      });
      if (error) throw error;
      return { id: rawId, status: "inserted", payment_id: data };
    }

    const fromAccount = account;
    const toAccount = resolveAccount(row.to_account ?? row.conta_destino, ctx)
      ?? inferTransferTarget(description, fromAccount, ctx);
    if (!fromAccount || !toAccount) {
      return { id: rawId, status: "needs_review", error: "transfer_accounts_required" };
    }
    const { data, error } = await supabase.rpc("sheet_sync_register_transfer", {
      p_space_id: spaceId,
      p_from_account_id: fromAccount.id,
      p_to_account_id: toAccount.id,
      p_amount: amount,
      p_description: description,
      p_occurred_at: occurredAt,
      p_external_id: externalId,
    });
    if (error) throw error;
    return { id: rawId, status: "inserted", event_id: data };
  }

  // Qualquer gasto novo entra SEM categoria econômica da planilha.
  // O usuário escolhe a categoria no app.
  if (card) {
    const { data, error } = await supabase.rpc("sheet_sync_register_card_purchase", {
      p_space_id: spaceId,
      p_card_id: card.id,
      p_total_amount: amount,
      p_description: description,
      p_installments_count: parseInstallments(row),
      p_category_id: null,
      p_purchase_at: occurredAt,
      p_merchant: String(row.merchant ?? description),
      p_external_id: externalId,
    });
    if (error) throw error;
    await markNeedsClassification(supabase, spaceId, externalId, originalCategory);
    return { id: rawId, status: "inserted", purchase_id: data };
  }

  if (!account) return { id: rawId, status: "error", error: "expense_account_not_found" };
  let data: any;
  let error: any;
  if (account.type === "benefit") {
    ({ data, error } = await supabase.rpc("sheet_sync_register_benefit", {
      p_space_id: spaceId,
      p_account_id: account.id,
      p_amount: amount,
      p_description: description,
      p_is_credit: false,
      p_category_id: null,
      p_occurred_at: occurredAt,
      p_external_id: externalId,
    }));
  } else {
    ({ data, error } = await supabase.rpc("sheet_sync_register_expense", {
      p_space_id: spaceId,
      p_account_id: account.id,
      p_amount: amount,
      p_description: description,
      p_category_id: null,
      p_occurred_at: occurredAt,
      p_competence_date: dateOnly(occurredAt),
      p_external_id: externalId,
    }));
  }
  if (error) throw error;
  await markNeedsClassification(supabase, spaceId, externalId, originalCategory);
  return { id: rawId, status: "inserted", event_id: data };
}

async function pullRows(supabase: any, spaceId: string, since: string, limit: number, ctx: Context) {
  const scanLimit = Math.min(2000, Math.max(500, limit * 4));
  const { data: scanned, error } = await supabase.from("financial_events")
    .select("id,event_type,description,amount,occurred_at,competence_date,category_id,status,source,external_id,metadata,updated_at")
    .eq("space_id", spaceId)
    .eq("status", "confirmed")
    .gt("updated_at", since)
    .order("updated_at", { ascending: true })
    .limit(scanLimit);
  if (error) throw error;
  if (!scanned?.length) return { rows: [], cursor: since };

  const cursor = scanned[scanned.length - 1].updated_at;
  const events = scanned.filter((event: any) => {
    if (event.source === "app") return true;
    return event.metadata?.sheet_linked === true && event.metadata?.needs_classification === false;
  }).slice(0, limit);
  if (!events.length) return { rows: [], cursor };

  const ids = events.map((e: any) => e.id);
  const { data: impacts, error: impactsError } = await supabase.from("financial_impacts")
    .select("event_id,dimension,amount,account_id")
    .in("event_id", ids);
  if (impactsError) throw impactsError;

  const impactsByEvent = new Map<string, any[]>();
  for (const impact of impacts ?? []) {
    if (!impactsByEvent.has(impact.event_id)) impactsByEvent.set(impact.event_id, []);
    impactsByEvent.get(impact.event_id)!.push(impact);
  }

  const rows = events.map((event: any) => {
    const category = event.category_id ? ctx.categoriesById.get(event.category_id) ?? null : null;
    const eventImpacts = impactsByEvent.get(event.id) ?? [];
    const accountImpact = eventImpacts.find((i) =>
      (i.dimension === "cash" || i.dimension === "benefit") && i.account_id
    );
    const account = accountImpact?.account_id ? ctx.accountsById.get(accountImpact.account_id) : null;
    const cardId = event.metadata?.card_id as string | undefined;
    const card = cardId ? ctx.cardsById.get(cardId) : null;

    let type = "Despesa";
    if (["income", "benefit_credit", "reimbursement"].includes(event.event_type)) type = "Receita";
    if (["transfer", "reserve_transfer", "card_payment"].includes(event.event_type)) type = "Transferência";

    let paymentMethod = "Conta";
    if (event.event_type === "card_purchase") paymentMethod = "Cartão";
    if (["benefit_credit", "benefit_expense"].includes(event.event_type)) paymentMethod = "Benefício";
    if (type === "Transferência") paymentMethod = "Transferência";

    return {
      id: event.external_id ? String(event.external_id).replace(/^sheet:/, "") : `event:${event.id}`,
      event_type: event.event_type,
      occurred_at: event.occurred_at,
      payment_method: paymentMethod,
      description: event.description,
      amount: Number(event.amount),
      type,
      category: sheetCategory(category),
      category_path: category ? categoryPath(category, ctx) : null,
      account_card: card?.name ?? account?.name ?? "",
      card_last_four: card?.last_four ?? null,
      installments_count: Number(event.metadata?.installments_count ?? 1),
      status: "Confirmado",
      source: "Fôlego App",
      updated_at: event.updated_at,
    };
  });
  return { rows, cursor };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        ...JSON_HEADERS,
        "access-control-allow-origin": "*",
        "access-control-allow-headers": "content-type,x-spreadsheet-id,x-folego-sync-token",
      },
    });
  }
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json(500, { error: "server_config_missing" });
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const spreadsheetId = req.headers.get("x-spreadsheet-id")?.trim() ?? "";
  const token = req.headers.get("x-folego-sync-token") ?? "";
  if (!spreadsheetId || !token) return json(401, { error: "sync_credentials_required" });

  const { data: integration, error: integrationError } = await supabase
    .from("sheet_sync_integrations")
    .select("id,space_id,spreadsheet_id,token_hash,enabled")
    .eq("spreadsheet_id", spreadsheetId)
    .eq("enabled", true)
    .maybeSingle();
  if (integrationError) return json(500, { error: "integration_lookup_failed" });
  if (!integration || await sha256(token) !== integration.token_hash) {
    return json(401, { error: "invalid_sync_credentials" });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const action = String(body.action ?? "").toLowerCase();
  const spaceId = integration.space_id as string;

  try {
    if (action === "health") {
      return json(200, { ok: true, space_id: spaceId, spreadsheet_id: spreadsheetId, mode: "app-classifies" });
    }
    const ctx = await loadContext(supabase, spaceId);

    if (action === "push") {
      const rows = Array.isArray(body.rows) ? body.rows.slice(0, 200) : (body.row ? [body.row] : []);
      const results = [];
      for (const row of rows) {
        try {
          results.push(await pushRow(supabase, spaceId, row, ctx));
        } catch (error) {
          results.push({
            id: String(row?.id ?? ""),
            status: "error",
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
      await supabase.from("sheet_sync_integrations")
        .update({ last_push_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq("id", integration.id);
      return json(200, { ok: true, results });
    }

    if (action === "pull") {
      const since = body.since ? toIso(body.since) : new Date(Date.now() - 30 * 86400000).toISOString();
      const limit = Math.max(1, Math.min(500, Number(body.limit ?? 200)));
      const result = await pullRows(supabase, spaceId, since, limit, ctx);
      await supabase.from("sheet_sync_integrations")
        .update({ last_pull_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq("id", integration.id);
      return json(200, { ok: true, ...result });
    }

    return json(400, { error: "unknown_action" });
  } catch (error) {
    return json(500, {
      error: "sync_failed",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});
