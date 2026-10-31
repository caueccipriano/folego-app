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
