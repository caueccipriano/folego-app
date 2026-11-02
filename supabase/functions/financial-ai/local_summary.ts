// Read-only, deterministic monthly summary. This is NOT generative AI.
// The input must be server-verified canonical aggregates, not user-sent totals.
// No finance writes, model calls, or Premium quota are needed.

export interface VerifiedMoney {
  month: string;
  income: number;
  expenses: number;
  result: number;
  categories?: {
    name: string;
    budgetUsed: number;
    budgetLimit: number | null;
    currentComparable: number;
    previousComparable: number;
    difference: number;
  }[];
  comparison?: {
    daysOneTo: number;
    currentMonth: string;
    previousMonth: string;
  };
  pendingClassificationAmount?: number;
}

export interface ReviewFocus {
  kind: string;
  title: string;
  description: string;
}

function finite(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

const currency = (number: number): string =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency', currency: 'BRL', maximumFractionDigits: 2,
  }).format(number);

export function localFinancialSummary(
  data: VerifiedMoney, focus: ReviewFocus | null,
): string {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(data.month) ||
      !finite(data.income) || !finite(data.expenses) ||
      !finite(data.result)) {
    throw new Error('Canonical totals unavailable');
  }
  const lines = [
    'Resumo automático de ' + data.month + ' (sem IA):',
    'Receitas registradas: ' + currency(data.income) + '.',
    'Despesas por competência: ' + currency(data.expenses) + '.',
    'Resultado do mês: ' + currency(data.result) + '.',
  ];
  if (data.result < 0) {
    lines.push('As despesas registradas superam as receitas em ' +
      currency(Math.abs(data.result)) + '.');
  } else if (data.result > 0) {
    lines.push('O resultado registrado está positivo. Isso não é o saldo bancário.');
  } else {
    lines.push('Receitas e despesas registradas estão equilibradas.');
  }
  if (data.categories && data.categories.length > 0 && data.comparison &&
      Number.isInteger(data.comparison.daysOneTo) &&
      data.comparison.daysOneTo > 0 && data.comparison.daysOneTo <= 31) {
    const reviewed = data.categories.slice(0, 2).filter((category) =>
      finite(category.currentComparable) &&
      finite(category.previousComparable) &&
      typeof category.name === 'string');
    if (reviewed.length > 0) {
      lines.push('Comparação parcial das categorias analisadas, dias 1 a ' +
        data.comparison.daysOneTo + ':');
      for (const category of reviewed) {
        const label = category.name.replace(/[\r\n]/g, ' ').slice(0, 42);
        lines.push(label + ': ' +
          currency(category.currentComparable) + ' neste mês, ' +
          currency(category.previousComparable) + ' no anterior.');
      }
    }
  }
  if (focus && typeof focus.title === 'string' && focus.title.length <= 100) {
    lines.push('Uma coisa para revisar: ' + focus.title + '.');
  }
  lines.push('Valores baseados nos registros do Fôlego, não em saldo bancário confirmado.');
  return lines.join('\n');
}
