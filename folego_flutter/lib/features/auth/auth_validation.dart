abstract final class AuthValidation {
  static const int minimumPasswordLength = 8;

  static final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe $label.';
    }
    return null;
  }

  static String? firstName(String? value) {
    return requiredField(value, 'seu nome');
  }

  static String? lastName(String? value) {
    return requiredField(value, 'seu sobrenome');
  }

  static String? email(String? value) {
    final required = requiredField(value, 'seu e-mail');
    if (required != null) return required;

    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Confira o e-mail.';
    }
    return null;
  }

  static String? password(
    String? value, {
    bool enforceMinimum = false,
  }) {
    final required = requiredField(value, 'sua senha');
    if (required != null) return required;

    if (enforceMinimum && value!.length < minimumPasswordLength) {
      return 'Use pelo menos $minimumPasswordLength caracteres.';
    }
    return null;
  }

  static String? emailConfirmation(String? value, String email) {
    final validation = AuthValidation.email(value);
    if (validation != null) return validation;

    if (value!.trim().toLowerCase() != email.trim().toLowerCase()) {
      return 'Os e-mails precisam ser iguais.';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    final required = requiredField(value, 'a confirmação da senha');
    if (required != null) return required;

    if (value != password) {
      return 'As senhas precisam ser iguais.';
    }
    return null;
  }

  static String fullName(String firstName, String lastName) {
    return '${firstName.trim()} ${lastName.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
