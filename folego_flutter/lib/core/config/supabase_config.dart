abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ycumrvkwqizlnehelhek.supabase.co',
  );

  // Publishable key: intentionally safe for client-side applications.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_8K5nfby9LmhIJh3B-knQAg_fSUqItLL',
  );
}
