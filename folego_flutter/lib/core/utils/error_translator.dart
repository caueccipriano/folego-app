import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduz erros técnicos (Postgres/Supabase/Auth) em mensagens amigáveis.
/// Nunca deve deixar passar SQL cru, código de erro ou detalhes internos.
abstract final class ErrorTranslator {
  static String forDisplay(Object error) {
    if (error is FormatException) return error.message;
    if (error is AuthException) return _fromAuth(error);
    if (error is PostgrestException) return _fromPostgrest(error);
    if (error is StateError) {
      return 'Não conseguimos carregar suas informações agora.';
    }

    final message = error.toString().toLowerCase();
    if (_looksLikeNetworkError(message)) {
      return 'Não foi possível conectar agora. Verifique sua rede e tente de novo.';
    }
    return 'Não conseguimos concluir agora. Tente novamente em instantes.';
  }

  static String _fromAuth(AuthException error) {
    final message = error.message.toLowerCase();

    if (_looksLikeNetworkError(message)) {
      return 'Não foi possível conectar agora. Verifique sua rede e tente de novo.';
    }
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'E-mail ou senha não conferem.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar. Verifique sua caixa de entrada.';
    }
    if (message.contains('already registered') ||
        message.contains('user already registered')) {
      return 'Já existe uma conta com esse e-mail.';
    }
    if (message.contains('invalid email') ||
        message.contains('unable to validate email')) {
      return 'Confira o e-mail informado.';
    }
    if (message.contains('password should be at least') ||
        message.contains('weak password')) {
      return 'Essa senha não atende aos requisitos. Use pelo menos 10 caracteres.';
    }
    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Muitas tentativas seguidas. Aguarde um instante e tente de novo.';
    }
    return 'Não foi possível concluir. Verifique seus dados e tente novamente.';
  }

  static bool _looksLikeNetworkError(String message) {
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network') ||
        message.contains('connection refused') ||
        message.contains('connection reset');
  }

  static String _fromPostgrest(PostgrestException error) {
    final message = error.message.toLowerCase();

    if (message.contains('not allowed') || message.contains('permission')) {
      return 'Você não tem permissão para alterar essas finanças.';
    }
    if (message.contains('space') && message.contains('member')) {
      return 'Você não tem acesso a este espaço financeiro.';
    }

    switch (error.code) {
      case '23505':
        return 'Já existe um registro com esses dados.';
      case '23503':
        return 'Não é possível concluir: um item relacionado não foi encontrado.';
      case '23502':
        return 'Preencha todos os campos obrigatórios.';
      case '23514':
        return 'Um dos valores informados não é válido.';
      case '42501':
        return 'Você não tem permissão para fazer isso.';
      case 'PGRST116':
        return 'Não encontramos essa informação.';
      default:
        return 'Não conseguimos salvar agora. Tente novamente.';
    }
  }
}
