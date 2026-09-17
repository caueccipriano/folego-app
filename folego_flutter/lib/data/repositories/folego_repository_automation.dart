import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/automation_rule.dart';
import 'folego_repository.dart';

const _automationSelect = '''
  id,space_id,name,active,match_field,match_type,match_value,source_scope_type,
  source_account_id,source_card_id,source_benefit_id,direction,category_id,
  classification_value,action_type,execution_mode,priority
''';

extension FolegoRepositoryAutomation on FolegoRepository {
  Future<List<AutomationRule>> listAutomationRules(String spaceId) async {
    final data = await Supabase.instance.client
        .from('automation_rules')
        .select(_automationSelect)
        .eq('space_id', spaceId)
        .order('priority', ascending: false)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data)
        .map(AutomationRule.fromJson)
        .toList(growable: false);
  }

  Future<AutomationRule> createAutomationRule({
    required String spaceId,
    required AutomationRuleDraft draft,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão necessária para criar automações.');
    }
    final data = await Supabase.instance.client
        .from('automation_rules')
        .insert(draft.toWriteJson(spaceId: spaceId, createdBy: userId))
        .select(_automationSelect)
        .single();
    return AutomationRule.fromJson(data);
  }

  Future<AutomationRule> updateAutomationRule({
    required String spaceId,
    required String ruleId,
    required AutomationRuleDraft draft,
  }) async {
    final payload = draft.toWriteJson(spaceId: spaceId)
      ..remove('space_id')
      ..remove('created_by');
    final data = await Supabase.instance.client
        .from('automation_rules')
        .update(payload)
        .eq('space_id', spaceId)
        .eq('id', ruleId)
        .select(_automationSelect)
        .single();
    return AutomationRule.fromJson(data);
  }

  Future<void> setAutomationRuleActive({
    required String spaceId,
    required String ruleId,
    required bool active,
  }) async {
    await Supabase.instance.client
        .from('automation_rules')
        .update(<String, dynamic>{'active': active})
        .eq('space_id', spaceId)
        .eq('id', ruleId);
  }

  Future<void> deleteAutomationRule({
    required String spaceId,
    required String ruleId,
  }) async {
    await Supabase.instance.client
        .from('automation_rules')
        .delete()
        .eq('space_id', spaceId)
        .eq('id', ruleId);
  }

  Future<int> applyAutomationRulesToImportBatch({
    required String spaceId,
    required String batchId,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'apply_automation_rules_to_import_batch',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
      },
    );
    return (data as num?)?.toInt() ?? 0;
  }
}
