enum GoalStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const GoalStatus(this.value);
  final String value;

  static GoalStatus fromValue(String? value) {
    return GoalStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => GoalStatus.active,
    );
  }
}

enum GoalIcon {
  plane('plane'),
  deviceLaptop('device-laptop'),
  car('car'),
  home('home'),
  gift('gift'),
  piggyBank('piggy-bank');

  const GoalIcon(this.key);
  final String key;

  static GoalIcon fromKey(String? key) {
    return GoalIcon.values.firstWhere(
      (icon) => icon.key == key,
      orElse: () => GoalIcon.piggyBank,
    );
  }
}

class FinancialGoal {
  const FinancialGoal({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.target,
    required this.icon,
    required this.status,
    required this.currentAmount,
    required this.createdAt,
    required this.updatedAt,
    this.targetDate,
    this.completedAt,
  });

  final String id;
  final String spaceId;
  final String name;
  final num target;
  final DateTime? targetDate;
  final GoalIcon icon;
  final GoalStatus status;
  final num currentAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  double get progress {
    if (target <= 0) return 0;
    return (currentAmount / target).toDouble();
  }

  double get visualProgress => progress.clamp(0.0, 1.0).toDouble();

  int get progressPercent => (visualProgress * 100).round();

  num get remaining {
    final value = target - currentAmount;
    return value > 0 ? value : 0;
  }

  bool get isActive => status == GoalStatus.active;
  bool get isCompleted => status == GoalStatus.completed;
  bool get isArchived => status == GoalStatus.archived;

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    final contributions = json['goal_contributions'];
    num currentAmount = json['current_amount'] as num? ?? 0;

    if (contributions is List) {
      currentAmount = contributions.fold<num>(0, (total, raw) {
        if (raw is Map) {
          return total + (raw['amount'] as num? ?? 0);
        }
        return total;
      });
    }

    return FinancialGoal(
      id: json['id'] as String,
      spaceId: json['space_id'] as String,
      name: json['name'] as String,
      target: json['target'] as num,
      targetDate: _dateOrNull(json['target_date']),
      icon: GoalIcon.fromKey(json['icon_key'] as String?),
      status: GoalStatus.fromValue(json['status'] as String?),
      currentAmount: currentAmount,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['created_at']) as String,
      ),
      completedAt: _dateOrNull(json['completed_at']),
    );
  }
}

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.spaceId,
    required this.amount,
    required this.contributedAt,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String goalId;
  final String spaceId;
  final num amount;
  final DateTime contributedAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GoalContribution.fromJson(Map<String, dynamic> json) {
    return GoalContribution(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      spaceId: json['space_id'] as String,
      amount: json['amount'] as num,
      contributedAt: DateTime.parse(
        (json['contributed_at'] ?? json['created_at']) as String,
      ),
      note: (json['note'] as String?)?.trim(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['created_at']) as String,
      ),
    );
  }
}

class GoalDetails {
  const GoalDetails({required this.goal, required this.contributions});

  final FinancialGoal goal;
  final List<GoalContribution> contributions;
}

num totalActiveGoalAmount(Iterable<FinancialGoal> goals) {
  return goals
      .where((goal) => goal.status == GoalStatus.active)
      .fold<num>(0, (total, goal) => total + goal.currentAmount);
}

List<GoalContribution> sortGoalContributionsNewestFirst(
  Iterable<GoalContribution> contributions,
) {
  final result = contributions.toList();
  result.sort((a, b) {
    final byDate = b.contributedAt.compareTo(a.contributedAt);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  });
  return result;
}

DateTime? _dateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
