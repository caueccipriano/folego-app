import 'package:flutter_test/flutter_test.dart';

import 'package:folego/features/auth/auth_validation.dart';

void main() {
  group('AuthValidation login', () {
    test('e-mail é obrigatório e precisa ser válido', () {
      expect(AuthValidation.email(''), isNotNull);
      expect(AuthValidation.email('caue'), 'Confira o e-mail.');
      expect(AuthValidation.email('caue@example.com'), isNull);
    });

    test('senha é obrigatória no login', () {
      expect(AuthValidation.password(''), isNotNull);
      expect(AuthValidation.password('123'), isNull);
    });
  });

  group('AuthValidation cadastro', () {
    test('nome e sobrenome são obrigatórios', () {
      expect(AuthValidation.firstName(''), isNotNull);
      expect(AuthValidation.lastName('  '), isNotNull);
      expect(AuthValidation.firstName('Cauê'), isNull);
      expect(AuthValidation.lastName('Cipriano'), isNull);
    });

    test('confirmação de e-mail precisa ser igual', () {
      expect(
        AuthValidation.emailConfirmation('', 'caue@example.com'),
        isNotNull,
      );
      expect(
        AuthValidation.emailConfirmation(
          'outro@example.com',
          'caue@example.com',
        ),
        'Os e-mails precisam ser iguais.',
      );
      expect(
        AuthValidation.emailConfirmation(
          'CAUE@example.com',
          'caue@example.com',
        ),
        isNull,
      );
    });

    test('senha de cadastro exige pelo menos 8 caracteres', () {
      expect(
        AuthValidation.password('1234567', enforceMinimum: true),
        contains('8 caracteres'),
      );
      expect(
        AuthValidation.password('12345678', enforceMinimum: true),
        isNull,
      );
    });

    test('confirmação de senha é obrigatória e precisa ser igual', () {
      expect(AuthValidation.passwordConfirmation('', '12345678'), isNotNull);
      expect(
        AuthValidation.passwordConfirmation('87654321', '12345678'),
        'As senhas precisam ser iguais.',
      );
      expect(
        AuthValidation.passwordConfirmation('12345678', '12345678'),
        isNull,
      );
    });

    test('fullName normaliza espaços sem duplicar armazenamento', () {
      expect(
        AuthValidation.fullName('  Glauber Cauê ', ' Cipriano  '),
        'Glauber Cauê Cipriano',
      );
    });
  });
}
