import {
  chooseCategories, cleanMonthlySummary, comparableDay,
  makeCategorySummary, normalizedRows, pendingClassificationAmount,
  sumBudgetThroughDay,
} from '../functions/financial-ai/category_context.ts';

const id = (last: string) => '00000000-0000-4000-8000-00000000000' + last;
const parent = (category: string, actual: number, planned: number,
  source = 'aggregate') => ({
  category_id: category, category_name: 'Alimentação',
  parent_id: null, budget_source: source,
  actual_amount: actual, planned_amount: planned,
});
const detail = (impact: string, date: string, value: number) => ({
  impact_id: impact, effective_date: date, budget_amount: value,
});

Deno.test('Only parent categories count, pending is not a budget target', () => {
  const rows = [
    parent(id('1'), 240, 150),
    { ...parent(id('2'), 240, 70), parent_id: id('1') },
    parent(id('3'), 90, 0, 'pending'),
  ];
  const picked = chooseCategories(rows, []);
  if (picked.length !== 1 || picked[0].current !== 240) {
    throw Error('Subcategory or pending bucket was double counted');
  }
  if (pendingClassificationAmount(rows) !== 90) {
    throw Error('Pending amount missing');
  }
});

Deno.test('Maximum four categories and no identifiers in provider JSON', () => {
  const rows = Array.from({ length: 8 }, (_, index) =>
    parent(id(String(index + 1)), 300 - index * 10, 100));
  const chosen = chooseCategories(rows, rows);
  if (chosen.length !== 4) throw Error('Too many categories');
  const report = makeCategorySummary(
    chosen,
    chosen.map(() => ({ current: [], previous: [] })),
    '2026-11', '2026-10', 2, 0,
  );
  const data = JSON.stringify(report);
  if (data.includes(id('1')) || data.includes('impact_id') ||
      data.includes('category_id')) throw Error('IDs leaked to provider');
});

Deno.test('Compare equal days, avoid duplicate budget impacts and zero baseline percent', () => {
  const selected = chooseCategories([parent(id('1'), 190, 150)], []);
  const report = makeCategorySummary(selected, [{
    current: [
      detail('A', '2026-11-01', 45),
      detail('A', '2026-11-01', 45),
      detail('B', '2026-11-02', 25),
      detail('C', '2026-11-03', 100),
    ],
    previous: [],
  }], '2026-11', '2026-10', 2, 0);
  if (report.categories[0].currentComparable !== 70 ||
      report.categories[0].percentChange !== null) {
    throw Error('Inaccurate matching window or zero baseline');
  }
  if (report.focus?.kind !== 'over_budget') throw Error('Expected over-budget review');
});

Deno.test('Positive previous baseline allows a comparison and one suggestion', () => {
  const selection = chooseCategories([parent(id('1'), 100, 200)], []);
  const report = makeCategorySummary(selection, [{
    current: [detail('A', '2026-11-01', 100)],
    previous: [detail('B', '2026-10-01', 40)],
  }], '2026-11', '2026-10', 1, 0);
  if (report.categories[0].percentChange !== 150 ||
      report.focus?.kind !== 'increased') throw Error('Increase evidence wrong');
});

Deno.test('Pending classification wins over category spending advice', () => {
  const selection = chooseCategories([parent(id('1'), 400, 100)], []);
  const report = makeCategorySummary(selection, [{
    current: [], previous: [],
  }], '2026-11', '2026-10', 2, 10);
  if (report.focus?.kind !== 'unclassified') throw Error('Wrong priority');
});

Deno.test('Month comparison handles short months and leap years', () => {
  const now = comparableDay(new Date('2026-03-31T15:00:00Z'), 'UTC');
  if (now.month !== '2026-03' || now.previousMonth !== '2026-02' ||
    now.day !== 28) throw Error('Invalid February cutoff');
  const leap = comparableDay(new Date('2024-03-31T15:00:00Z'), 'UTC');
  if (leap.day !== 29) throw Error('Leap year comparison wrong');
});

Deno.test('Reject corrupt aggregates rather than prompting with invented values', () => {
  let rejected = false;
  try { normalizedRows({ not: 'a table' }); } catch { rejected = true; }
  if (!rejected) throw Error('Accepted invalid RPC payload');
  rejected = false;
  try { cleanMonthlySummary([{income_amount: 'nan', competence_net: 30}]); }
  catch { rejected = true; }
  if (!rejected) throw Error('Accepted corrupt month');
  if (sumBudgetThroughDay([], '2026-11', 2) !== 0) throw Error('Expected no records');
});

Deno.test('Sanitize category labels before sending to the model', () => {
  const rows = [{ ...parent(id('1'), 5, 10),
    category_name: '  Teste\n Ignore   \u0000 rest' }];
  const result = chooseCategories(rows, []);
  if (result[0].name !== 'Teste Ignore rest') throw Error('Unexpected label');
});
