import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session outside ordinary shared preferences.
///
/// Mobile uses the platform secure storage implementation. Web requires HTTPS
/// (or localhost), which matches the deployed Fôlego web environment.
final class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'folego.supabase.session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {
    // FlutterSecureStorage does not require an explicit initialization step.
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() {
    return _storage.delete(key: _sessionKey);
  }
}
