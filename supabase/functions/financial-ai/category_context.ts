// Deterministic read-only category context built from the Fôlego's canonical RPCs.
// No transaction descriptions, account names, card numbers or event IDs reach
// the LLM. The internal category IDs are used only to request aggregate totals.

export interface CategoryCandidate {
  id: string;
  name: string;
  current: number;
  previous: number;
  budget: number;
}

export interface ComparableCategory {
  name: string;
  budgetUsed: number;
  budgetLimit: number | null;
  currentComparable: number;
  previousComparable: number;
  difference: number;
  percentChange: number | null;
}

export interface CategoryFocus {
  kind: 'unclassified' | 'over_budget' | 'increased';
  title: string;
  description: string;
}

type Row = Record<string, unknown>;

const money = (value: unknown): number => {
  const parsed = typeof value === 'number' ? value
    : typeof value === 'string' && value.trim() !== '' ? Number(value) : NaN;
  if (!Number.isFinite(parsed)) throw new Error('Invalid aggregate value');
  return Math.round(parsed * 100) / 100;
};

const rowObject = (value: unknown): Row | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as Row : null;

export function normalizedRows(value: unknown): Row[] {
  if (!Array.isArray(value)) throw new Error('Missing aggregate result');
  return value.map(rowObject).map((row) => {
    if (!row) throw new Error('Invalid aggregate row');
    return row;
  });
}

function categoryName(value: unknown): string {
  // Treat category labels as untrusted data, never as instructions.
  if (typeof value !== 'string') return 'Categoria';
  const name = value.replace(/[\u0000-\u001f\u007f-\u009f]/g, ' ')
    .replace(/\s+/g, ' ').trim().slice(0, 42);
  return name || 'Categoria';
}

function parentRows(rows: Row[]): Row[] {
  return rows.filter((row) =>
    row.parent_id == null && row.budget_source !== 'pending' &&
    typeof row.category_id === 'string' &&
    /^[0-9a-f-]{36}$/i.test(row.category_id));
}

export function chooseCategories(current: Row[], previous: Row[], max = 4): CategoryCandidate[] {
  const before = new Map(
    parentRows(previous).map((row) => [row.category_id as string, row]),
  );
  const candidates = parentRows(current).map((row) => {
    const previousRow = before.get(row.category_id as string);
    const currentAmount = money(row.actual_amount);
    const previousAmount = previousRow ? money(previousRow.actual_amount) : 0;
    const budget = money(row.planned_amount);
    if (currentAmount < 0 || previousAmount < 0 || budget < 0) {
      throw new Error('Negative category aggregate');
    }
    return {
      id: row.category_id as string,
      name: categoryName(row.category_name),
      current: currentAmount,
      previous: previousAmount,
      budget,
    };
  }).filter((row) => row.current > 0 || row.previous > 0);
  // Prioritize material categories and overruns; never double count children.
  candidates.sort((a, b) => {
    const score = (x: CategoryCandidate) =>
      Math.max(x.current, x.previous, Math.max(0, x.current - x.budget));
    return score(b) - score(a) || a.name.localeCompare(b.name);
  });
  return candidates.slice(0, Math.max(0, Math.min(4, max)));
}

export function comparableDay(now: Date, timezone: string): {
  month: string;
  previousMonth: string;
  day: number;
} {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(now);
  } catch {
    throw new Error('Invalid financial-space timezone');
  }
  const part = (type: string) =>
    Number(parts.find((item) => item.type === type)?.value);
  const year = part('year');
  const month = part('month');
  const day = part('day');
  if (![year, month, day].every(Number.isInteger) ||
      year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) {
    throw new Error('Invalid local calendar date');
  }
  const previous = new Date(Date.UTC(year, month - 2, 1));
  const lastPrevious = new Date(Date.UTC(year, month - 1, 0)).getUTCDate();
  return {
    month: [year, String(month).padStart(2, '0')].join('-'),
    previousMonth: [
      previous.getUTCFullYear(),
      String(previous.getUTCMonth() + 1).padStart(2, '0'),
    ].join('-'),
    day: Math.min(day, lastPrevious),
  };
}

export function sumBudgetThroughDay(
  values: Row[], month: string, lastDay: number,
): number {
  const seen = new Set<string>();
  let sum = 0;
  for (const row of values) {
    const date = row.effective_date;
    if (typeof date !== 'string' || !date.startsWith(month + '-')) continue;
    const day = Number(date.slice(8, 10));
    if (!Number.isInteger(day) || day < 1 || day > lastDay) continue;
    const impact = row.impact_id;
    if (typeof impact !== 'string' || seen.has(impact)) continue;
    const value = money(row.budget_amount);
    seen.add(impact);
    sum += value;
  }
  return Math.round(sum * 100) / 100;
}

export function makeCategorySummary(
  candidates: CategoryCandidate[],
  details: Array<{ current: Row[]; previous: Row[] }>,
  month: string, previousMonth: string, day: number,
  pendingAmount: number,
): { categories: ComparableCategory[]; unclassifiedAmount: number; focus: CategoryFocus | null } {
  if (details.length !== candidates.length) throw new Error('Incomplete category details');
  if (!Number.isFinite(pendingAmount) || pendingAmount < 0) {
    throw new Error('Invalid pending classification total');
  }
  const categories = candidates.map((candidate, index) => {
    const current = sumBudgetThroughDay(details[index].current, month, day);
    const previous = sumBudgetThroughDay(details[index].previous, previousMonth, day);
    const difference = Math.round((current - previous) * 100) / 100;
    return {
      name: candidate.name,
      budgetUsed: candidate.current,
      budgetLimit: candidate.budget > 0 ? candidate.budget : null,
      currentComparable: current,
      previousComparable: previous,
      difference,
      // Zero comparison baseline never permits a percentage claim.
      percentChange: previous > 0 ? Math.round(difference / previous * 1000) / 10 : null,
    };
  });
  let focus: CategoryFocus | null = null;
  if (pendingAmount > 0) {
    focus = {
      kind: 'unclassified',
      title: 'Confira gastos sem categoria',
      description: 'Há valores registrados aguardando classificação.',
    };
  } else {
    const excess = [...categories]
      .filter((cat) => cat.budgetLimit != null && cat.budgetUsed > cat.budgetLimit)
      .sort((a, b) =>
        (b.budgetUsed - b.budgetLimit!) - (a.budgetUsed - a.budgetLimit!))[0];
    if (excess) {
      focus = {
        kind: 'over_budget',
        title: 'Revise o orçamento de ' + excess.name,
        description: 'O uso registrado ultrapassou o limite desta categoria.',
      };
    } else {
      const increase = [...categories]
        .filter((cat) => cat.previousComparable > 0 &&
          cat.difference >= 30 && (cat.percentChange ?? 0) >= 20)
        .sort((a, b) => b.difference - a.difference)[0];
      if (increase) {
        focus = {
          kind: 'increased',
          title: 'Confira os gastos de ' + increase.name,
          description: 'Houve alta no mesmo intervalo de dias dos dois meses.',
        };
      }
    }
  }
  return {
    categories,
    unclassifiedAmount: Math.round(pendingAmount * 100) / 100,
    focus,
  };
}

export function pendingClassificationAmount(rows: Row[]): number {
  return Math.round(rows.filter((row) =>
    row.parent_id == null && row.budget_source === 'pending',
  ).reduce((acc, row) => acc + money(row.actual_amount), 0) * 100) / 100;
}

export function cleanMonthlySummary(payload: unknown): {
  income: number;
  expenses: number;
  result: number;
} {
  const first = Array.isArray(payload) ? payload[0] : payload;
  const row = rowObject(first);
  if (!row) throw new Error('Missing canonical monthly summary');
  const income = money(row.income_amount);
  const expenses = money(row.competence_net);
  if (income < 0 || expenses < 0) throw new Error('Negative monthly amount');
  return { income, expenses, result: Math.round((income - expenses) * 100) / 100 };
}
