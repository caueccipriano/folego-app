import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';

void main() {
  test('6 temas com 2 modos e tokens completos', () {
    expect(FolegoColorTokens.catalog.map((p) => p.id).toSet().length, 6);
    for (final palette in FolegoColorTokens.catalog) {
      for (final brightness in Brightness.values) {
        final t = FolegoColorTokens.fromId(palette.id, brightness);
        final context = '${palette.name} $brightness';
        expect(FolegoColorTokens.contrastRatio(t.textoPrincipal, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context texto');
        expect(FolegoColorTokens.contrastRatio(t.textoSecundario, t.superficie),
          greaterThanOrEqualTo(4.5), reason: '$context secundario');
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
