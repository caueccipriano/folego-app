import 'dart:convert';

/// Converts only trusted provider identifiers and known HTTP statuses into
/// concise user-visible feedback. Never displays raw upstream error payloads.
String? financialAiProviderName(Object? provider) {
  switch (provider) {
    case 'gemini':
      return 'Gemini';
    case 'openai':
      return 'OpenAI';
    default:
      return null;
  }
}

String financialAiErrorMessage(int status, Object? details) {
  Object? decoded = details;
  if (details is String && details.length <= 600) {
    try {
      decoded = jsonDecode(details);
    } catch (_) {
      // Upstream plain text is untrusted; show only generic status feedback.
    }
  }
  final body = decoded is Map ? decoded : null;
  final error = body?['error'];
  // The function sends short, pre-approved messages. Unknown provider
  // responses must not be rendered raw (they may contain sensitive content).
  if (error == 'Sem acesso ao espaço financeiro.') {
    return 'Sem acesso a este espaço financeiro.';
  }
  if (error == 'Disponível para Premium, até 30 perguntas por mês.') {
    return 'A IA está disponível no Premium, com até 30 perguntas por mês.';
  }
  if (error == 'Assistente ainda não configurado.') {
    return 'O provedor de IA ainda não foi configurado no servidor.';
  }
  switch (status) {
    case 400:
      return 'Confira a pergunta e tente novamente.';
    case 401:
      return 'Sua sessão expirou. Entre novamente para consultar.';
    case 403:
      return 'Seu plano ou acesso ao espaço não permite essa consulta.';
    case 429:
      return 'Muitas consultas em sequência. Tente mais tarde.';
    case 502:
      return 'A IA não respondeu agora. Você pode tentar novamente.';
    case 503:
      return 'A análise financeira está indisponível no momento.';
    default:
      return 'Não foi possível consultar a IA. Seus dados seguem intactos.';
  }
}
