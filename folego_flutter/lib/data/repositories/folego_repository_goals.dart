import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/financial_goal.dart';
import 'folego_repository.dart';

extension FolegoRepositoryGoals on FolegoRepository {
  Future<List<FinancialGoal>> listGoals(String spaceId) async {
    final response = await Supabase.instance.client
        .from('savings_goals')
        .select('''
          id,
          space_id,
          name,
          target,
          target_date,
          icon_key,
          status,
          created_at,
          updated_at,
          completed_at,
          goal_contributions(amount)
        ''')
        .eq('space_id', spaceId)
        .neq('status', GoalStatus.archived.value)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(FinancialGoal.fromJson)
        .toList();
  }

  Future<GoalDetails> getGoalDetails({
    required String spaceId,
    required String goalId,
  }) async {
    final response = await Supabase.instance.client
        .from('savings_goals')
        .select('''
          id,
          space_id,
          name,
          target,
          target_date,
          icon_key,
          status,
          created_at,
          updated_at,
          completed_at,
          goal_contributions(amount)
        ''')
        .eq('space_id', spaceId)
        .eq('id', goalId)
        .single();

    final goal = FinancialGoal.fromJson(Map<String, dynamic>.from(response));
    final contributions = await listGoalContributions(
      spaceId: spaceId,
      goalId: goalId,
    );

    return GoalDetails(goal: goal, contributions: contributions);
  }

  Future<String> createGoal({
    required String spaceId,
    required String name,
    required num target,
    required GoalIcon icon,
    DateTime? targetDate,
  }) async {
    _validateGoal(name: name, target: target);

    final response = await Supabase.instance.client
        .from('savings_goals')
        .insert({
          'space_id': spaceId,
          'name': name.trim(),
          'target': target,
          'target_date': targetDate == null ? null : _goalDate(targetDate),
          'icon_key': icon.key,
          'status': GoalStatus.active.value,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<void> updateGoal({
    required String spaceId,
    required String goalId,
    required String name,
    required num target,
    required GoalIcon icon,
    DateTime? targetDate,
  }) async {
    _validateGoal(name: name, target: target);

    await Supabase.instance.client
        .from('savings_goals')
        .update({
          'name': name.trim(),
          'target': target,
          'target_date': targetDate == null ? null : _goalDate(targetDate),
          'icon_key': icon.key,
        })
        .eq('space_id', spaceId)
        .eq('id', goalId);
  }

  Future<void> archiveGoal({
    required String spaceId,
    required String goalId,
  }) async {
    await Supabase.instance.client
        .from('savings_goals')
        .update({'status': GoalStatus.archived.value})
        .eq('space_id', spaceId)
        .eq('id', goalId);
  }

  Future<String> addGoalContribution({
    required String spaceId,
    required String goalId,
    required num amount,
    required DateTime contributedAt,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('O aporte deve ser maior que zero.');
    }

    final normalizedNote = note?.trim();
    if (normalizedNote != null && normalizedNote.length > 300) {
      throw ArgumentError('A nota pode ter até 300 caracteres.');
    }

    final response = await Supabase.instance.client
        .from('goal_contributions')
        .insert({
          'space_id': spaceId,
          'goal_id': goalId,
          'amount': amount,
          'contributed_at': DateTime(
            contributedAt.year,
            contributedAt.month,
            contributedAt.day,
            12,
          ).toIso8601String(),
          'note': normalizedNote?.isEmpty == true ? null : normalizedNote,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<GoalContribution>> listGoalContributions({
    required String spaceId,
    required String goalId,
  }) async {
    final response = await Supabase.instance.client
        .from('goal_contributions')
        .select('''
          id,
          goal_id,
          space_id,
          amount,
          contributed_at,
          note,
          created_at,
          updated_at
        ''')
        .eq('space_id', spaceId)
        .eq('goal_id', goalId)
        .order('contributed_at', ascending: false)
        .order('created_at', ascending: false);

    return sortGoalContributionsNewestFirst(
      List<Map<String, dynamic>>.from(response).map(GoalContribution.fromJson),
    );
  }
}

void _validateGoal({required String name, required num target}) {
  final normalizedName = name.trim();
  if (normalizedName.isEmpty) {
    throw ArgumentError('Informe o nome da meta.');
  }
  if (normalizedName.length > 100) {
    throw ArgumentError('O nome da meta pode ter até 100 caracteres.');
  }
  if (target <= 0) {
    throw ArgumentError('O valor alvo deve ser maior que zero.');
  }
}

String _goalDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
