// Server-side Gemini adapter. Never embed a key or transaction-level data here.
export const defaultGeminiModel = 'gemini-3.5-flash-lite';

export function makeGeminiRequest(model: string, instructions: string, prompt: string) {
  return {
    url: 'https://generativelanguage.googleapis.com/v1beta/models/'
      + encodeURIComponent(model) + ':generateContent',
    body: {
      systemInstruction: { parts: [{ text: instructions }] },
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: 1024, temperature: 0.2 },
    },
  };
}

export function readGeminiAnswer(value: unknown): string {
  if (!value || typeof value !== 'object') return '';
  const candidates = (value as { candidates?: unknown }).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return '';
  const parts = candidates[0]?.content?.parts;
  if (!Array.isArray(parts)) return '';
  return parts
    .filter((part) => part && typeof part.text === 'string' && part.thought !== true)
    .map((part) => part.text as string).join('').trim();
}
