import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';

/// Evaluates basic currency arithmetic without executing arbitrary expressions.
/// Input is never persisted: callers only receive the confirmed final amount.
abstract final class BudgetAmountMath {
  static final RegExp _valid = RegExp(
    r'^\d+(?:\.\d+)?(?:[+\-*/]\d+(?:\.\d+)?)*$',
  );

  static num? evaluate(String raw) {
    final expression = raw.replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-');
    if (expression.length > 64 || !_valid.hasMatch(expression)) return null;
    final tokens = RegExp(r'\d+(?:\.\d+)?|[+\-*/]')
        .allMatches(expression)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    if (tokens.isEmpty || tokens.join() != expression) return null;

    var current = double.parse(tokens.first);
    final groups = <double>[];
    final additions = <String>[];
    for (var index = 1; index < tokens.length; index += 2) {
      final operation = tokens[index];
      final next = double.parse(tokens[index + 1]);
      switch (operation) {
        case '*':
          current *= next;
          break;
        case '/':
          if (next == 0) return null;
          current /= next;
          break;
        case '+':
        case '-':
          groups.add(current);
          additions.add(operation);
          current = next;
          break;
      }
      if (!current.isFinite) return null;
    }
    groups.add(current);
    var result = groups.first;
    for (var index = 0; index < additions.length; index++) {
      result = additions[index] == '+'
          ? result + groups[index + 1]
          : result - groups[index + 1];
    }
    if (!result.isFinite || result <= 0 || result > 999999999) return null;
    return (result * 100).round() / 100;
  }
}

/// A numeric keypad for a bottom sheet, with an explicit Apply action.
/// The parent quick-register form retains control of actual saving.
class QuickAmountCalculator extends StatefulWidget {
  const QuickAmountCalculator({super.key, this.initialValue});

  final num? initialValue;

  @override
  State<QuickAmountCalculator> createState() => _QuickAmountCalculatorState();
}

class _QuickAmountCalculatorState extends State<QuickAmountCalculator> {
  String _expression = '';

  static const _rows = <List<String>>[
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['C', '0', ',', '+'],
    ['⌫', '00', '=', 'OK'],
  ];

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    if (value != null && value > 0) {
      _expression = value.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  void _press(String key) {
    final amount = BudgetAmountMath.evaluate(_expression);
    if (key == 'OK') {
      if (amount != null) Navigator.of(context).pop(amount);
      return;
    }
    setState(() {
      if (key == 'C') {
        _expression = '';
      } else if (key == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (key == '=') {
        if (amount != null) {
          _expression = amount.toStringAsFixed(2).replaceAll('.', ',');
        }
      } else if (const ['÷', '×', '−', '+'].contains(key)) {
        if (_expression.isEmpty) return;
        if (RegExp(r'[+−×÷]) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _expression = '$_expression$key';
      } else if (key == ',') {
        final part = _expression.split(RegExp(r'[+−×÷]')).last;
        if (part.contains(',')) return;
        _expression = part.isEmpty ? '${_expression}0,' : '$_expression,';
      } else if (_expression.length < 32) {
        _expression = '$_expression$key';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    final preview = BudgetAmountMath.evaluate(_expression);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('calculadora', style: AppTypography.section(
                context, fontSize: 20, color: colors.textoPrincipal)),
            const SizedBox(height: 4),
            Text('Some ou divida valores antes de registrar.',
                style: AppTypography.body(
                    context, fontSize: 12, color: colors.textoSecundario)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.fundo,
                border: Border.all(color: colors.borda),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_expression.isEmpty ? '0' : _expression,
                      key: const ValueKey('budget-calculator-expression'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.money(context,
                          fontSize: 24, color: colors.textoPrincipal)),
                  const SizedBox(height: 5),
                  Text(preview == null ? 'digite uma expressão válida'
                      : Formatters.money(preview),
                      key: const ValueKey('budget-calculator-result'),
                      style: AppTypography.label(context,
                          fontSize: 12, color: colors.textoSecundario)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final row in _rows) ...[
              Row(children: [
                for (final label in row) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: OutlinedButton(
                        key: ValueKey('budget-calculator-key-$label'),
                        onPressed: () => _press(label),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 49),
                          padding: EdgeInsets.zero,
                          backgroundColor: label == 'OK'
                              ? colors.marca : colors.superficie,
                          foregroundColor: label == 'OK'
                              ? colors.marcaSobre : colors.textoPrincipal,
                          side: BorderSide(color: colors.borda),
                        ),
                        child: Text(label,
                            style: AppTypography.body(context,
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
            ],
          ],
        ),
      ),
    );
  }
}
).hasMatch(_expression)) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _expression = '$_expression$key';
      } else if (key == ',') {
        final part = _expression.split(RegExp(r'[+−×÷]')).last;
        if (part.contains(',')) return;
        _expression = part.isEmpty ? '${_expression}0,' : '$_expression,';
      } else if (_expression.length < 32) {
        _expression = '$_expression$key';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    final preview = BudgetAmountMath.evaluate(_expression);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('calculadora', style: AppTypography.section(
                context, fontSize: 20, color: colors.textoPrincipal)),
            const SizedBox(height: 4),
            Text('Some ou divida valores antes de registrar.',
                style: AppTypography.body(
                    context, fontSize: 12, color: colors.textoSecundario)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.fundo,
                border: Border.all(color: colors.borda),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_expression.isEmpty ? '0' : _expression,
                      key: const ValueKey('budget-calculator-expression'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.money(context,
                          fontSize: 24, color: colors.textoPrincipal)),
                  const SizedBox(height: 5),
                  Text(preview == null ? 'digite uma expressão válida'
                      : Formatters.money(preview),
                      key: const ValueKey('budget-calculator-result'),
                      style: AppTypography.label(context,
                          fontSize: 12, color: colors.textoSecundario)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final row in _rows) ...[
              Row(children: [
                for (final label in row) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: OutlinedButton(
                        key: ValueKey('budget-calculator-key-$label'),
                        onPressed: () => _press(label),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 49),
                          padding: EdgeInsets.zero,
                          backgroundColor: label == 'OK'
                              ? colors.marca : colors.superficie,
                          foregroundColor: label == 'OK'
                              ? colors.marcaSobre : colors.textoPrincipal,
                          side: BorderSide(color: colors.borda),
                        ),
                        child: Text(label,
                            style: AppTypography.body(context,
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
            ],
          ],
        ),
      ),
    );
  }
}
