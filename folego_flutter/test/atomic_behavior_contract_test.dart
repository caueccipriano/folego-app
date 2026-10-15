import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    '../supabase/sql_proposals/atomic_spending_behavior_review.sql',
  ).readAsStringSync();
  final repository = File(
    'lib/data/repositories/folego_repository.dart',
  ).readAsStringSync();

  test('proposed RPC is closed to anon and explicitly authorized', () {
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains("SET search_path = ''"));
    expect(sql, contains('auth.uid() IS NULL'));
    expect(sql, contains('private.can_write_space(p_space_id)'));
    expect(sql, contains('REVOKE ALL ON FUNCTION'));
    expect(sql, contains('FROM PUBLIC, anon'));
    expect(sql, contains('TO authenticated'));
    expect(sql, contains("e.space_id = p_space_id"));
    expect(sql, contains("e.status = 'confirmed'"));
    expect(sql, contains("e.event_type IN ('expense', 'card_purchase', 'benefit_expense')"));
  });

  test('row-lock and null-aware optimistic CAS prevent lost behavior updates', () {
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('v_current IS DISTINCT FROM p_expected_behavior_class'));
    expect(sql, contains("RAISE EXCEPTION 'annotation_conflict'"));
    expect(sql, contains('v_current IS DISTINCT FROM p_behavior_class'));
    expect(sql, contains('SET behavior_class = p_behavior_class'));
  });

  test('DB mutation never changes category, tags, amount or necessity', () {
    final procedure = sql
        .split(r'AS $folego_atomic_behavior[1]
        .split(r'$folego_atomic_behavior[0];
    final update = procedure
        .split('UPDATE public.financial_events')[1]
        .split('END IF;')[0];
    expect(update, contains('SET behavior_class = p_behavior_class'));
    expect(update, isNot(contains('necessity_class =')));
    expect(update, isNot(contains('frequency_class =')));
    expect(update, isNot(contains('category_id =')));
    expect(update, isNot(contains('amount =')));
    expect(procedure, isNot(contains('UPDATE public.financial_event_tags')));
    expect(procedure, isNot(contains('DELETE FROM public.financial_event_tags')));
    expect(procedure, isNot(contains('INSERT INTO public.financial_event_tags')));
  });

  test('client calls only atomic server function, not legacy overwrite RPC', () {
    final method = repository
        .split('Future<void> setSpendingBehavior({')[1]
        .split('// ESPAÇO / PERFIL')[0];
    expect(method, contains("'set_event_behavior_class'"));
    expect(method, contains("'p_expected_behavior_class': expected"));
    expect(method, contains("'p_behavior_class': next"));
    expect(method, contains("'p_event_id': entry.id"));
    expect(method, contains("'p_space_id': spaceId"));
    expect(method, isNot(contains('set_event_annotations')));
    expect(method, isNot(contains('financial_event_tags')));
    expect(method, isNot(contains('p_tag_ids')));
    expect(method, isNot(contains('necessity_class')));
    expect(method, isNot(contains('frequency_class')));
  });
}
)[1]
        .split('$folego_atomic_behavior$')[0];
    final update = procedure
        .split('UPDATE public.financial_events')[1]
        .split('END IF;')[0];
    expect(update, contains('SET behavior_class = p_behavior_class'));
    expect(update, isNot(contains('necessity_class =')));
    expect(update, isNot(contains('frequency_class =')));
    expect(update, isNot(contains('category_id =')));
    expect(update, isNot(contains('amount =')));
    expect(procedure, isNot(contains('UPDATE public.financial_event_tags')));
    expect(procedure, isNot(contains('DELETE FROM public.financial_event_tags')));
    expect(procedure, isNot(contains('INSERT INTO public.financial_event_tags')));
  });

  test('client calls only atomic server function, not legacy overwrite RPC', () {
    final method = repository
        .split('Future<void> setSpendingBehavior({')[1]
        .split('// ESPAÇO / PERFIL')[0];
    expect(method, contains("'set_event_behavior_class'"));
    expect(method, contains("'p_expected_behavior_class': expected"));
    expect(method, contains("'p_behavior_class': next"));
    expect(method, contains("'p_event_id': entry.id"));
    expect(method, contains("'p_space_id': spaceId"));
    expect(method, isNot(contains('set_event_annotations')));
    expect(method, isNot(contains('financial_event_tags')));
    expect(method, isNot(contains('p_tag_ids')));
    expect(method, isNot(contains('necessity_class')));
    expect(method, isNot(contains('frequency_class')));
  });
}
)[0];
    final update = procedure
        .split('UPDATE public.financial_events')[1]
        .split('END IF;')[0];
    expect(update, contains('SET behavior_class = p_behavior_class'));
    expect(update, isNot(contains('necessity_class =')));
    expect(update, isNot(contains('frequency_class =')));
    expect(update, isNot(contains('category_id =')));
    expect(update, isNot(contains('amount =')));
    expect(procedure, isNot(contains('UPDATE public.financial_event_tags')));
    expect(procedure, isNot(contains('DELETE FROM public.financial_event_tags')));
    expect(procedure, isNot(contains('INSERT INTO public.financial_event_tags')));
  });

  test('client calls only atomic server function, not legacy overwrite RPC', () {
    final method = repository
        .split('Future<void> setSpendingBehavior({')[1]
        .split('// ESPAÇO / PERFIL')[0];
    expect(method, contains("'set_event_behavior_class'"));
    expect(method, contains("'p_expected_behavior_class': expected"));
    expect(method, contains("'p_behavior_class': next"));
    expect(method, contains("'p_event_id': entry.id"));
    expect(method, contains("'p_space_id': spaceId"));
    expect(method, isNot(contains('set_event_annotations')));
    expect(method, isNot(contains('financial_event_tags')));
    expect(method, isNot(contains('p_tag_ids')));
    expect(method, isNot(contains('necessity_class')));
    expect(method, isNot(contains('frequency_class')));
  });
}
)[1]
        .split('$folego_atomic_behavior$')[0];
    final update = procedure
        .split('UPDATE public.financial_events')[1]
        .split('END IF;')[0];
    expect(update, contains('SET behavior_class = p_behavior_class'));
    expect(update, isNot(contains('necessity_class =')));
    expect(update, isNot(contains('frequency_class =')));
    expect(update, isNot(contains('category_id =')));
    expect(update, isNot(contains('amount =')));
    expect(procedure, isNot(contains('UPDATE public.financial_event_tags')));
    expect(procedure, isNot(contains('DELETE FROM public.financial_event_tags')));
    expect(procedure, isNot(contains('INSERT INTO public.financial_event_tags')));
  });

  test('client calls only atomic server function, not legacy overwrite RPC', () {
    final method = repository
        .split('Future<void> setSpendingBehavior({')[1]
        .split('// ESPAÇO / PERFIL')[0];
    expect(method, contains("'set_event_behavior_class'"));
    expect(method, contains("'p_expected_behavior_class': expected"));
    expect(method, contains("'p_behavior_class': next"));
    expect(method, contains("'p_event_id': entry.id"));
    expect(method, contains("'p_space_id': spaceId"));
    expect(method, isNot(contains('set_event_annotations')));
    expect(method, isNot(contains('financial_event_tags')));
    expect(method, isNot(contains('p_tag_ids')));
    expect(method, isNot(contains('necessity_class')));
    expect(method, isNot(contains('frequency_class')));
  });
}
