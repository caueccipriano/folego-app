import 'package:supabase_flutter/supabase_flutter.dart';

/// User-facing explanation for an intentionally blocked shared-owner delete.
/// The backend checks all financial spaces, not merely the space currently
/// selected on this device. Unknown errors continue through normal handling.
String? sharedAccountDeletionErrorMessage(Object error) {
  if (error is! FunctionException || error.status != 409) return null;
  final body = error.details;
  if (body is! Map ||
      body['error'] != 'shared_space_requires_resolution') {
    return null;
  }
  return 'sua conta é proprietária de um espaço financeiro compartilhado. '
      'para proteger os dados das outras pessoas, resolva a titularidade '
      'com o suporte antes de excluir a conta.';
}
