import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';

void main() {
  test('valor principal usa a cor de texto do hero, nunca rosa fixo', () {
    final source = File('lib/features/home/home_financial_hero.dart')
        .readAsStringSync();
    expect(source, contains('final heroValueColor = onPurple;'));
    expect(source, isNot(contains('final heroValueColor = spendable <= 0')));
    expect(source, isNot(contains('color: tokens.estouradoHero')));
  });

  test('hero numerico permanece legivel em todos os 15 temas e modos', () {
    for (final palette in FolegoColorTokens.catalog) {
      for (final brightness in Brightness.values) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        expect(
          FolegoColorTokens.contrastRatio(t.marcaHeroSobre, t.marcaHero),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} / $brightness',
        );
      }
    }
  });

  test('cores de alerta continuam semanticas, nao dirigem os digitos', () {
    for (final brightness in Brightness.values) {
      final baseline = FolegoColorTokens.fromId('folego', brightness);
      for (final palette in FolegoColorTokens.catalog) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        expect(t.folga, baseline.folga);
        expect(t.apertado, baseline.apertado);
        expect(t.estourado, baseline.estourado);
      }
    }
  });
}
