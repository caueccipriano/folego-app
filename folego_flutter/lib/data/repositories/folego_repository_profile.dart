import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_identity.dart';
import 'folego_repository.dart';

extension FolegoRepositoryProfile on FolegoRepository {
  Future<ProfileIdentity> getProfileIdentity() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final email = user?.email?.trim() ?? '';

    if (user == null) {
      return ProfileIdentity(email: email);
    }

    final response = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(response);
    final fullName = rows.isEmpty ? null : rows.first['full_name'] as String?;

    return ProfileIdentity(
      email: email,
      fullName: fullName,
    );
  }
}
