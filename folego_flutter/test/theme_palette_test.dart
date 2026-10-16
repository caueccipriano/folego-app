import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';

void main() {
  test('17 paletas coerentes com 2 modos e tokens completos', () {
    expect(FolegoColorTokens.catalog.map((p) => p.id).toSet().length, 17);
    for (final palette in FolegoColorTokens.catalog) {
      for (final brightness in Brightness.values) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        final context = '${palette.name} $brightness';
        expect(FolegoColorTokens.contrastRatio(t.textoPrincipal, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context texto');
        expect(FolegoColorTokens.contrastRatio(t.textoSecundario, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context secundario');
        expect(FolegoColorTokens.contrastRatio(t.marca, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context marca na superficie');
        expect(FolegoColorTokens.contrastRatio(t.marca, t.fundo),
          greaterThanOrEqualTo(4.5), reason: '$context marca no fundo');
        expect(FolegoColorTokens.contrastRatio(t.marcaSobre, t.marca),
          greaterThanOrEqualTo(4.5), reason: '$context marca');
        expect(FolegoColorTokens.contrastRatio(t.acaoSobre, t.acao),
          greaterThanOrEqualTo(4.5), reason: '$context acao');
        expect(FolegoColorTokens.contrastRatio(t.marcaHeroSobre, t.marcaHero),
          greaterThanOrEqualTo(4.5), reason: '$context hero');
        for (final value in [t.folga, t.apertado, t.estourado]) {
          expect(FolegoColorTokens.contrastRatio(value, t.superficie),
            greaterThanOrEqualTo(4.5), reason: '$context estado na superficie');
        }
        for (final value in [t.folgaHero, t.apertadoHero, t.estouradoHero]) {
          expect(FolegoColorTokens.contrastRatio(value, t.marcaHero),
            greaterThanOrEqualTo(3.0), reason: '$context estado no hero');
        }
      }
    }
  });

  test('cada paleta tem sua própria base clara e escura', () {
    final lightBackgrounds = <Color>{};
    final darkBackgrounds = <Color>{};
    for (final palette in FolegoColorTokens.catalog) {
      final light = FolegoColorTokens.fromId(palette.id, Brightness.light);
      final dark = FolegoColorTokens.fromId(palette.id, Brightness.dark);
      expect(light.fundo, isNot(dark.fundo), reason: palette.name);
      expect(light.superficie, isNot(dark.superficie), reason: palette.name);
      expect(light.marcaHero, isNot(dark.marcaHero), reason: palette.name);
      expect(palette.description, isNotEmpty);
      expect(lightBackgrounds.add(light.fundo), isTrue,
        reason: 'fundo claro repetido: ${palette.name}');
      expect(darkBackgrounds.add(dark.fundo), isTrue,
        reason: 'fundo escuro repetido: ${palette.name}');
    }
    // Preferências antigas permanecem estáveis ao ampliar o catálogo.
    for (final id in [
      'folego', 'mare', 'salvia', 'chiclete', 'tangerina', 'neon'
    ]) {
      expect(FolegoColorTokens.palette(id).id, id);
    }
    for (final id in [
      'safira', 'mochi', 'cacau',
      'matcha', 'pixel', 'cherry', 'butter', 'orbit', 'disco',
      'pistache_frost', 'terracota_gallery',
    ]) {
      expect(FolegoColorTokens.palette(id).id, id);
    }
  });

  test('referências Pistache Frost e Terracota Gallery preservam as cores originais', () {
    final frost = FolegoColorTokens.palette('pistache_frost');
    final gallery = FolegoColorTokens.palette('terracota_gallery');
    expect(frost.action, const Color(0xFFB9C255));
    expect(frost.lightBackground, const Color(0xFFE6F1FA));
    expect(frost.brand, const Color(0xFF5798D7));
    expect(gallery.brand, const Color(0xFFC34811));
    expect(gallery.action, const Color(0xFFD9D1CA));

    final frostLight = FolegoColorTokens.fromId(
      'pistache_frost', Brightness.light,
    );
    final galleryLight = FolegoColorTokens.fromId(
      'terracota_gallery', Brightness.light,
    );
    expect(frostLight.marcaHero, const Color(0xFF254A72));
    expect(galleryLight.marcaHero, const Color(0xFF0B369A));
    for (final id in ['pistache_frost', 'terracota_gallery']) {
      for (final mode in Brightness.values) {
        final tokens = FolegoColorTokens.fromId(id, mode);
        expect(FolegoColorTokens.contrastRatio(
          tokens.acaoHero, tokens.marcaHero,
        ), greaterThanOrEqualTo(4.5), reason: '$id $mode KPI');
      }
    }
  });

  test('ThemeData aplica tokens da própria paleta, sem herdar cores da anterior', () {
    final previous = AppColorSelection.selected.value;
    addTearDown(() => AppColorSelection.choose(previous));
    for (final palette in FolegoColorTokens.catalog) {
      AppColorSelection.choose(palette.id);
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark
            ? AppTheme.dark() : AppTheme.light();
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);
        expect(theme.scaffoldBackgroundColor, tokens.fundo);
        expect(theme.cardColor, tokens.superficie);
        expect(theme.colorScheme.primary, tokens.marca);
        expect(theme.colorScheme.secondary, tokens.acao);
        expect(theme.colorScheme.tertiary, tokens.acao);
        expect(theme.colorScheme.onSurface, tokens.textoPrincipal);
        expect(theme.colorScheme.surfaceContainer, tokens.superficie);
        expect(theme.colorScheme.surfaceContainerHigh, tokens.superficieAlta);
        expect(theme.colorScheme.onPrimaryContainer, tokens.textoPrincipal);
        expect(theme.colorScheme.onSecondaryContainer, tokens.textoPrincipal);
        expect(FolegoColorTokens.contrastRatio(
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ), greaterThanOrEqualTo(4.5));
        expect(theme.extension<FolegoColorTokens>()?.marcaHero, tokens.marcaHero);
      }
    }
  });

  test('seleção não modifica cores semânticas de estado', () {
    for (final brightness in Brightness.values) {
      final baseline = FolegoColorTokens.fromId('mare', brightness);
      for (final palette in FolegoColorTokens.catalog) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        expect(t.folga, baseline.folga);
        expect(t.apertado, baseline.apertado);
        expect(t.estourado, baseline.estourado);
      }
    }
  });
}
