import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';

void main() {
  const ids = <String>[
    'prisma_pastel', 'after_dark', 'ink',
    'velvet_berry', 'hyperblue', 'solar_pop',
  ];

  test('seis temas selecionáveis distintos e Prisma Pastel como padrão', () {
    expect(FolegoColorTokens.catalog.map((p) => p.id).toList(), ids);
    expect(FolegoColorTokens.catalog.map((p) => p.name).toList(), [
      'Prisma Pastel', 'After Dark', 'Ink',
      'Velvet Berry', 'Hyperblue', 'Solar Pop',
    ]);
    expect(AppColorSelection.selected.value, 'prisma_pastel');
  });

  test('seis temas possuem superfícies legíveis em modos claro e escuro', () {
    final lightBackgrounds = <Color>{};
    final darkBackgrounds = <Color>{};
    for (final palette in FolegoColorTokens.catalog) {
      final light = FolegoColorTokens.fromId(palette.id, Brightness.light);
      final dark = FolegoColorTokens.fromId(palette.id, Brightness.dark);
      expect(light.fundo, isNot(dark.fundo), reason: palette.name);
      expect(light.superficie, isNot(dark.superficie), reason: palette.name);
      expect(light.marcaHero, isNot(dark.marcaHero), reason: palette.name);
      expect(lightBackgrounds.add(light.fundo), isTrue);
      expect(darkBackgrounds.add(dark.fundo), isTrue);
      expect(palette.description, isNotEmpty);
      for (final brightness in Brightness.values) {
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);
        final label = palette.name + brightness.toString();
        for (final color in [tokens.textoPrincipal, tokens.textoSecundario, tokens.marca]) {
          expect(FolegoColorTokens.contrastRatio(color, tokens.superficie),
            greaterThanOrEqualTo(4.5), reason: label);
          expect(FolegoColorTokens.contrastRatio(color, tokens.fundo),
            greaterThanOrEqualTo(4.5), reason: label);
        }
        expect(FolegoColorTokens.contrastRatio(tokens.marcaSobre, tokens.marca),
          greaterThanOrEqualTo(4.5), reason: label);
        expect(FolegoColorTokens.contrastRatio(tokens.acaoSobre, tokens.acao),
          greaterThanOrEqualTo(4.5), reason: label);
        expect(FolegoColorTokens.contrastRatio(tokens.marcaHeroSobre, tokens.marcaHero),
          greaterThanOrEqualTo(4.5), reason: label);
        expect(FolegoColorTokens.contrastRatio(tokens.acaoHero, tokens.marcaHero),
          greaterThanOrEqualTo(4.5), reason: label);
        for (final color in [tokens.folga, tokens.apertado, tokens.estourado]) {
          expect(FolegoColorTokens.contrastRatio(color, tokens.superficie),
            greaterThanOrEqualTo(4.5), reason: label);
        }
        for (final color in [tokens.folgaHero, tokens.apertadoHero, tokens.estouradoHero]) {
          expect(FolegoColorTokens.contrastRatio(color, tokens.marcaHero),
            greaterThanOrEqualTo(3.0), reason: label);
        }
      }
    }
  });

  test('miniaturas de temas têm acentos distintos', () {
    for (final id in ids) {
      expect(FolegoColorTokens.previewAccents(id, Brightness.light).length,
        greaterThanOrEqualTo(3), reason: id);
    }
    expect(FolegoColorTokens.previewAccents('prisma_pastel', Brightness.light).length, 5);
    expect(FolegoColorTokens.previewAccents('prisma_pastel', Brightness.dark).length, 5);
  });

  test('28 paletas antigas migram para os seis temas aprovados', () {
    const migration = <String, String>{
      'fluxo':'ink', 'folego':'prisma_pastel',
      'pistache_frost':'prisma_pastel', 'terracota_gallery':'solar_pop',
      'mare':'prisma_pastel', 'salvia':'prisma_pastel',
      'chiclete':'velvet_berry', 'tangerina':'solar_pop',
      'neon':'after_dark', 'safira':'hyperblue',
      'mochi':'prisma_pastel', 'cacau':'solar_pop',
      'matcha':'prisma_pastel', 'pixel':'hyperblue',
      'cherry':'velvet_berry', 'butter':'solar_pop',
      'orbit':'after_dark', 'disco':'velvet_berry',
      'terracota':'solar_pop', 'indigopop':'velvet_berry',
      'oldlace':'ink', 'discofever':'after_dark',
      'bruma':'ink', 'jet':'ink',
      'acidblue':'hyperblue', 'popart':'solar_pop',
      'forestclub':'solar_pop', 'hyperblue':'hyperblue',
    };
    for (final entry in migration.entries) {
      expect(FolegoColorTokens.palette(entry.key).id, entry.value,
        reason: entry.key);
    }
    expect(FolegoColorTokens.palette('nonexistent').id, 'prisma_pastel');
  });

  test('ThemeData recebe a versão clara/escura de cada tema', () {
    final previous = AppColorSelection.selected.value;
    addTearDown(() => AppColorSelection.choose(previous));
    for (final palette in FolegoColorTokens.catalog) {
      AppColorSelection.choose(palette.id);
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);
        expect(theme.scaffoldBackgroundColor, tokens.fundo);
        expect(theme.cardColor, tokens.superficie);
        expect(theme.colorScheme.primary, tokens.marca);
        expect(theme.colorScheme.secondary, tokens.acao);
        expect(theme.colorScheme.onSurface, tokens.textoPrincipal);
        expect(theme.colorScheme.surfaceContainerHigh, tokens.superficieAlta);
      }
    }
  });

  test('cores financeiras semânticas são constantes entre os seis temas', () {
    for (final brightness in Brightness.values) {
      final baseline = FolegoColorTokens.fromId('prisma_pastel', brightness);
      for (final id in ids) {
        final theme = FolegoColorTokens.fromId(id, brightness);
        expect(theme.folga, baseline.folga);
        expect(theme.apertado, baseline.apertado);
        expect(theme.estourado, baseline.estourado);
      }
    }
  });
}
