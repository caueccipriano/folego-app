// Keep upstream diagnostics deliberately coarse: never log provider messages,
// prompts, financial totals, request identifiers, session details or API keys.
export type ProviderFailureKind =
  | 'credit_or_spend_limit'
  | 'provider_configuration'
  | 'provider_rate_or_unclassified_limit'
  | 'provider_unavailable';

export interface ProviderFailure {
  kind: ProviderFailureKind;
  status: 502 | 503;
  message: string;
}

const billingCodes = new Set([
  'insufficient_quota',
  'credit_balance_exhausted',
  'organization_usage_limit_exceeded',
  'organization_spend_limit_exceeded',
  'project_spend_limit_exceeded',
]);
const configurationCodes = new Set(['model_not_found', 'invalid_api_key']);

export function classifyProviderFailure(
  httpStatus: number, code: unknown, type: unknown,
): ProviderFailure {
  const identifiers = [code, type].filter(
    (value): value is string => typeof value === 'string',
  );
  if (identifiers.some((value) => billingCodes.has(value))) {
    return {
      kind: 'credit_or_spend_limit',
      status: 503,
      message: 'O serviço de IA atingiu um limite de créditos ou uso. '
        + 'Seu resumo sem IA continua disponível. Nenhuma pergunta descontada.',
    };
  }
  if (httpStatus === 401 || httpStatus === 403 ||
      identifiers.some((value) => configurationCodes.has(value))) {
    return {
      kind: 'provider_configuration',
      status: 503,
      message: 'O assistente está em manutenção de configuração. '
        + 'Nenhuma pergunta descontada.',
    };
  }
  if (httpStatus === 429 ||
      identifiers.some((value) => value === 'rate_limit_exceeded')) {
    // Unknown 429s can be a rate limit OR an unknown billing code. Do not
    // promise that merely retrying will restore service.
    return {
      kind: 'provider_rate_or_unclassified_limit',
      status: 503,
      message: 'O provedor de IA informou um limite de uso. '
        + 'O resumo sem IA continua disponível. Nenhuma pergunta descontada.',
    };
  }
  return {
    kind: 'provider_unavailable',
    status: 502,
    message: 'O serviço de IA não conseguiu concluir a resposta. '
      + 'Tente novamente mais tarde; nenhuma pergunta descontada.',
  };
}
