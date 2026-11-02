import { defaultGeminiModel, makeGeminiRequest, readGeminiAnswer } from '../functions/financial-ai/gemini_adapter.ts';

Deno.test('Gemini request has no API key and preserves instructions', () => {
  const request = makeGeminiRequest(defaultGeminiModel, 'Do not invent totals', 'Resumo: {"income":100}');
  if (!request.url.endsWith('/models/gemini-3.5-flash-lite:generateContent')) throw Error('Bad Gemini model path');
  const body = JSON.stringify(request.body);
  if (!body.includes('Do not invent totals') || !body.includes('income')) throw Error('Missing prompt');
  if (request.url.includes('key=') || body.includes('GEMINI_API_KEY')) throw Error('Secret in request');
});

Deno.test('Gemini reply uses visible text only', () => {
  const output = readGeminiAnswer({ candidates: [{ content: { parts: [
    {text:'Seu mês '}, {text:'private notes',thought:true}, {text:'está organizado.'}
  ] } }] });
  if (output !== 'Seu mês está organizado.') throw Error('Invalid visible reply');
  if (readGeminiAnswer({ candidates: [{finishReason:'SAFETY'}] }) !== '') throw Error('Unsafe empty output');
});

Deno.test('financial-ai uses Gemini exclusively', async () => {
  const source = await Deno.readTextFile(new URL('../functions/financial-ai/index.ts', import.meta.url));
  if (!source.includes("const provider = 'gemini'")) throw Error('Gemini must be the fixed provider');
  if (!source.includes("Deno.env.get('gemini')")) throw Error('Must read existing lowercase gemini secret');
  for (const forbidden of ['OPENAI_API_KEY', 'api.openai.com', 'FOLEGO_AI_PROVIDER', 'gpt-4']) {
    if (source.includes(forbidden)) throw Error('Legacy provider reference: ' + forbidden);
  }
});
