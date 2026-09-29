import { classifyProviderFailure } from './provider_error.ts';

function expectFailure(
  status: number, code: unknown, type: unknown,
  kind: ReturnType<typeof classifyProviderFailure>['kind'],
) {
  const found = classifyProviderFailure(status, code, type);
  if (found.kind !== kind) {
    throw new Error('Expected ' + kind + ', got ' + found.kind);
  }
  if (found.message.includes('tente agora')) {
    throw new Error('Never promise immediate recovery without provider data.');
  }
}

Deno.test('distinguish credit exhaustion by error.type even with null code', () => {
  expectFailure(429, null, 'insufficient_quota', 'credit_or_spend_limit');
});

Deno.test('recognize current API credit and usage error codes', () => {
  for (const code of [
    'credit_balance_exhausted',
    'organization_usage_limit_exceeded',
    'organization_spend_limit_exceeded',
    'project_spend_limit_exceeded',
  ]) {
    expectFailure(429, code, null, 'credit_or_spend_limit');
  }
});

Deno.test('unclassified HTTP 429 is a limit of unknown cause, not billing certainty', () => {
  expectFailure(429, null, null, 'provider_rate_or_unclassified_limit');
});

Deno.test('report transient request rate limits without claiming credit exhaustion', () => {
  expectFailure(429, 'rate_limit_exceeded', null, 'provider_rate_or_unclassified_limit');
});

Deno.test('provider auth and model access errors are configuration failures', () => {
  expectFailure(401, null, null, 'provider_configuration');
  expectFailure(400, 'model_not_found', null, 'provider_configuration');
});

Deno.test('other provider failures remain generic', () => {
  expectFailure(500, null, null, 'provider_unavailable');
});

Deno.test('unknown identifiers cannot be reflected in user messages or logs', () => {
  const unknown = 'secret-or-untrusted-provider-text';
  const result = classifyProviderFailure(429, unknown, unknown);
  if (JSON.stringify(result).includes(unknown)) {
    throw new Error('Unexpectedly returned raw provider content.');
  }
});