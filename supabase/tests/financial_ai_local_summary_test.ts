import { localFinancialSummary } from '../functions/financial-ai/local_summary.ts';

const money = (overrides: Record<string, unknown> = {}) => ({
  month: '2026-11',
  income: 6000,
  expenses: 4300,
  result: 1700,
  ...overrides,
});

Deno.test('Local summary uses official totals and never mistakes result for bank balance', () => {
  const text = localFinancialSummary(money(), null);
  if (!text.includes('6.000,00') || !text.includes('4.300,00') ||
      !text.includes('1.700,00') || !text.includes('não é o saldo bancário')) {
    throw Error('Incorrect summary or misleading result');
  }
  if (!text.includes('(sem IA)')) throw Error('Must disclose non-generative result');
});

Deno.test('Negative monthly result is reported as expense gap', () => {
  const text = localFinancialSummary(money({expenses: 7000,result: -1000}), null);
  if (!text.includes('superam as receitas em') || !text.includes('1.000,00')) {
    throw Error('Negative budget result not explained');
  }
});

Deno.test('Comparable category values are only compared for same days', () => {
  const text = localFinancialSummary(money({
    categories: [{
      name: 'Alimentação', currentComparable: 100, previousComparable: 50,
      difference: 50, budgetUsed: 500, budgetLimit: 300,
    }],
    comparison: {daysOneTo:2,currentMonth:'2026-11',previousMonth:'2026-10'},
  }), {kind:'over_budget',title:'Revise o orçamento de Alimentação',
    description:'Acima do limite'});
  if (!text.includes('dias 1 a 2') ||
      !text.includes('100,00') || !text.includes('50,00') ||
      !text.includes('Revise o orçamento')) {
    throw Error('Category comparison or focus omitted');
  }
});

Deno.test('Never invent category history when data unavailable', () => {
  const text = localFinancialSummary(money(), null);
  if (text.includes('Comparação parcial') || text.includes('Alimentação')) {
    throw Error('Invented category data');
  }
});

Deno.test('Reject unverified or nonfinite totals', () => {
  for (const totals of [
    money({income:NaN}), money({expenses:Infinity}), money({month:'oops'}),
  ]) {
    let rejected = false;
    try { localFinancialSummary(totals, null); } catch { rejected = true; }
    if (!rejected) throw Error('Invalid totals must not be displayed');
  }
});

Deno.test('Provider fallback never contains transaction IDs or description fields', () => {
  const text = localFinancialSummary(money(), null);
  if (text.includes('transaction_id') || text.includes('purchase_description') ||
      text.includes('accountId')) throw Error('Sensitive data in response');
});
