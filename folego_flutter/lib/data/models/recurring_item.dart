class RecurringItem {
  const RecurringItem({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.itemType,
    required this.amount,
    required this.frequency,
    required this.startsOn,
    required this.certainty,
    required this.active,
    this.dayOfMonth,
    this.monthlyDays = const [],
    this.monthlyLastDay = false,
    this.weekday,
    this.monthOfYear,
    this.categoryId,
    this.accountId,
    this.cardId,
    this.endsOn,
    this.categoryName,
    this.accountName,
  });

  final String id;
  final String spaceId;
  final String name;
  final String itemType;
  final double amount;
  final String frequency;

  final int? dayOfMonth;

  /// Dias fixos do mês.
  ///
  /// Exemplo:
  /// [5]
  /// [15, 30]
  final List<int> monthlyDays;

  /// Quando true, também ocorre no último
  /// dia real de cada mês.
  ///
  /// Fevereiro -> 28/29
  /// Abril -> 30
  /// Dezembro -> 31
  final bool monthlyLastDay;

  /// PostgreSQL DOW:
  /// 0 = domingo
  /// 1 = segunda
  /// ...
  /// 6 = sábado
  final int? weekday;

  final int? monthOfYear;

  final String? categoryId;
  final String? accountId;
  final String? cardId;

  final DateTime startsOn;
  final DateTime? endsOn;

  final String certainty;
  final bool active;

  final String? categoryName;
  final String? accountName;

  bool get isIncome => itemType == 'income';

  bool get isExpense => itemType == 'expense';

  String get typeLabel =>
      isIncome ? 'Receita' : 'Gasto';

  String get frequencyLabel {
    switch (frequency) {
      case 'weekly':
        return 'Toda semana';

      case 'biweekly':
        return 'A cada 2 semanas';

      case 'monthly':
        return 'Todo mês';

      case 'yearly':
        return 'Todo ano';

      default:
        return frequency;
    }
  }

  String get scheduleLabel {
    switch (frequency) {
      case 'weekly':
        if (weekday == null) {
          return 'Toda semana';
        }

        return 'Toda ${_weekdayLabel(weekday!)}';

      case 'biweekly':
        return 'A cada 2 semanas';

      case 'monthly':
        return _monthlyScheduleLabel();

      case 'yearly':
        if (dayOfMonth == null ||
            monthOfYear == null) {
          return 'Todo ano';
        }

        return 'Todo dia $dayOfMonth de ${_monthLabel(monthOfYear!)}';

      default:
        return frequencyLabel;
    }
  }

  String _monthlyScheduleLabel() {
    final days = monthlyDays
        .where(
          (day) => day >= 1 && day <= 31,
        )
        .toSet()
        .toList()
      ..sort();

    // Compatibilidade com recorrências antigas.
    if (days.isEmpty &&
        dayOfMonth != null &&
        !monthlyLastDay) {
      return 'Todo dia $dayOfMonth';
    }

    if (days.isEmpty &&
        monthlyLastDay) {
      return 'Último dia do mês';
    }

    if (days.length == 1 &&
        !monthlyLastDay) {
      return 'Todo dia ${days.first}';
    }

    final parts = <String>[
      ...days.map(
        (day) => 'dia $day',
      ),
      if (monthlyLastDay)
        'último dia',
    ];

    if (parts.length == 2) {
      return 'Todo mês · ${parts[0]} e ${parts[1]}';
    }

    if (parts.length > 2) {
      final last = parts.removeLast();

      return 'Todo mês · ${parts.join(', ')} e $last';
    }

    return 'Todo mês';
  }

  factory RecurringItem.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawCategory =
        json['category'] ??
            json['categories'];

    final rawAccount =
        json['account'] ??
            json['accounts'];

    Map<String, dynamic>? category;

    if (rawCategory is Map) {
      category =
          Map<String, dynamic>.from(
        rawCategory,
      );
    }

    Map<String, dynamic>? account;

    if (rawAccount is Map) {
      account =
          Map<String, dynamic>.from(
        rawAccount,
      );
    }

    final rawMonthlyDays =
        json['monthly_days'];

    final monthlyDays = <int>[];

    if (rawMonthlyDays is List) {
      for (final value in rawMonthlyDays) {
        if (value is num) {
          monthlyDays.add(
            value.toInt(),
          );
        }
      }
    }

    monthlyDays.sort();

    return RecurringItem(
      id: json['id'] as String,
      spaceId:
          json['space_id'] as String,
      name:
          json['name'] as String,
      itemType:
          json['item_type'] as String,
      amount:
          (json['amount'] as num)
              .toDouble(),
      frequency:
          json['frequency'] as String,
      dayOfMonth:
          _intOrNull(
        json['day_of_month'],
      ),
      monthlyDays:
          monthlyDays,
      monthlyLastDay:
          json['monthly_last_day']
                  as bool? ??
              false,
      weekday:
          _intOrNull(
        json['weekday'],
      ),
      monthOfYear:
          _intOrNull(
        json['month_of_year'],
      ),
      categoryId:
          json['category_id']
              as String?,
      accountId:
          json['account_id']
              as String?,
      cardId:
          json['card_id']
              as String?,
      startsOn: DateTime.parse(
        json['starts_on'] as String,
      ),
      endsOn:
          json['ends_on'] == null
              ? null
              : DateTime.parse(
                  json['ends_on']
                      as String,
                ),
      certainty:
          json['certainty']
                  as String? ??
              'confirmed',
      active:
          json['active'] as bool? ??
              true,
      categoryName:
          category?['name']
              as String?,
      accountName:
          account?['name']
              as String?,
    );
  }

  static int? _intOrNull(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static String _weekdayLabel(
    int weekday,
  ) {
    switch (weekday) {
      case 0:
        return 'domingo';

      case 1:
        return 'segunda-feira';

      case 2:
        return 'terça-feira';

      case 3:
        return 'quarta-feira';

      case 4:
        return 'quinta-feira';

      case 5:
        return 'sexta-feira';

      case 6:
        return 'sábado';

      default:
        return 'semana';
    }
  }

  static String _monthLabel(
    int month,
  ) {
    switch (month) {
      case 1:
        return 'janeiro';

      case 2:
        return 'fevereiro';

      case 3:
        return 'março';

      case 4:
        return 'abril';

      case 5:
        return 'maio';

      case 6:
        return 'junho';

      case 7:
        return 'julho';

      case 8:
        return 'agosto';

      case 9:
        return 'setembro';

      case 10:
        return 'outubro';

      case 11:
        return 'novembro';

      case 12:
        return 'dezembro';

      default:
        return '';
    }
  }
}