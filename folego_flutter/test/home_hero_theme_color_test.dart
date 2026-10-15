import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/features/home/home_financial_hero.dart';

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
  test('valor secundário usa cor de ação na base Cacau sem mudar o KPI', () {
    for (final brightness in Brightness.values) {
      final tokens = FolegoColorTokens.fromId('cacau', brightness);
      expect(tokens.acaoHero, tokens.acao);
      expect(tokens.acaoHero, isNot(tokens.marcaHeroSobre));
      expect(FolegoColorTokens.contrastRatio(
        tokens.acaoHero, tokens.marcaHero,
      ), greaterThanOrEqualTo(4.5));
    }
  });

  test('Maré e Butter ajustam o acento para contraste no hero', () {
    for (final palette in FolegoColorTokens.catalog) {
      for (final brightness in Brightness.values) {
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);
        expect(FolegoColorTokens.contrastRatio(
          tokens.acaoHero, tokens.marcaHero,
        ), greaterThanOrEqualTo(4.5), reason: '${palette.name} / $brightness');
      }
    }
    final mare = FolegoColorTokens.fromId('mare', Brightness.light);
    final butter = FolegoColorTokens.fromId('butter', Brightness.light);
    expect(mare.acaoHero, isNot(mare.acao));
    expect(butter.acaoHero, isNot(butter.acao));
  });

  test('apenas quantias recebem o acento: datas e texto ficam neutros', () {
    const accent = Color(0xFFC5F18C);
    const original = 'em contas: R\$ 62,90 · protegido: R\$ 487,49';
    final spans = heroCurrencySpans(original, accent);
    expect(spans.map((s) => s.text).join(), original);
    expect(
      spans.where((s) => s.style?.color == accent).map((s) => s.text).toList(),
      ['R\$ 62,90', 'R\$ 487,49'],
    );
    final dateSpans = heroCurrencySpans('recebe em 16 dias · 31 out', accent);
    expect(dateSpans.where((s) => s.style?.color == accent), isEmpty);
    expect(dateSpans.map((s) => s.text).join(), 'recebe em 16 dias · 31 out');
  });

  test('estrutura do card principal preserva valor neutro e realça detalhes', () {
    final source = File('lib/features/home/home_financial_hero.dart')
        .readAsStringSync();
    expect(source, contains('final heroValueColor = onPurple;'));
    expect(source, contains('heroCurrencySpans(contextCopy, tokens.acaoHero)'));
    expect(source, contains('heroCurrencySpans(fact, tokens.acaoHero)'));
  });

}
