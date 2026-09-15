import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/core/utils/error_translator.dart';

void main() {
  group('ErrorTranslator auth', () {
    test('traduz credenciais inválidas sem expor erro técnico', () {
      final result = ErrorTranslator.forDisplay(
        AuthException('invalid login credentials'),
      );
      expect(result, 'E-mail ou senha não conferem.');
    });

    test('traduz e-mail não confirmado', () {
      final result = ErrorTranslator.forDisplay(
        AuthException('email not confirmed'),
      );
      expect(result, contains('Confirme seu e-mail'));
    });

    test('traduz senha fraca', () {
      final result = ErrorTranslator.forDisplay(
        AuthException('password should be at least 6 characters'),
      );
      expect(result, contains('pelo menos 6 caracteres'));
    });

    test('traduz falha de rede', () {
      final result = ErrorTranslator.forDisplay(
        Exception('SocketException: Failed host lookup'),
      );
      expect(result, contains('Não foi possível conectar agora'));
    });
  });
}
