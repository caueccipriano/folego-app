import 'package:flutter/material.dart';

/// Tokens semânticos da camada visual. Nenhuma regra financeira vive aqui.
@immutable
class FolegoColorTokens extends ThemeExtension<FolegoColorTokens> {
  const FolegoColorTokens({
    required this.marca,
    required this.marcaSobre,
    required this.marcaHero,
    required this.marcaHeroSobre,
    required this.acao,
    required this.acaoSobre,
    required this.fundo,
    required this.superficie,
    required this.superficieAlta,
    required this.textoPrincipal,
    required this.textoSecundario,
    required this.borda,
    required this.folga,
    required this.folgaSobre,
    required this.apertado,
    required this.apertadoSobre,
    required this.estourado,
    required this.estouradoSobre,
    required this.folgaHero,
    required this.apertadoHero,
    required this.estouradoHero,
  });

  final Color marca, marcaSobre, marcaHero, marcaHeroSobre;
  final Color acao, acaoSobre;
  final Color fundo, superficie, superficieAlta;
  final Color textoPrincipal, textoSecundario, borda;
  final Color folga, folgaSobre, apertado, apertadoSobre;
  final Color estourado, estouradoSobre;
  final Color folgaHero, apertadoHero, estouradoHero;

  static const catalog = <FolegoPalette>[
    FolegoPalette('folego', 'Fôlego', Color(0xFF6C3CE9),
        Color(0xFFC6F135), Color(0xFFF5F1E8), Color(0xFF101014)),
    FolegoPalette('mare', 'Maré', Color(0xFF0F8B8D),
        Color(0xFFFF7A59), Color(0xFFF1F7F6), Color(0xFF0B1B1C)),
    FolegoPalette('salvia', 'Sálvia', Color(0xFF5F8F6B),
        Color(0xFFFFB88A), Color(0xFFF4F6F1), Color(0xFF121A14)),
    FolegoPalette('chiclete', 'Chiclete', Color(0xFFE0488F),
        Color(0xFF7CD7FF), Color(0xFFFFF3F8), Color(0xFF1D0F18)),
    FolegoPalette('tangerina', 'Tangerina', Color(0xFFF26B1D),
        Color(0xFFFFD23F), Color(0xFFFFF6EE), Color(0xFF1C120B)),
    FolegoPalette('neon', 'Neon', Color(0xFF2B3040),
        Color(0xFF19E0F0), Color(0xFFF3F5F8), Color(0xFF0A0C10)),
  ];

  static FolegoPalette palette(String id) =>
      catalog.firstWhere((item) => item.id == id, orElse: () => catalog.first);

  static FolegoColorTokens fromId(String id, Brightness brightness) {
    final p = palette(id);
    final dark = brightness == Brightness.dark;
    final originalBrand = p.id == 'folego'
        ? (dark ? const Color(0xFF967CF4) : p.brand)
        : (dark ? Color.lerp(p.brand, const Color(0xFFFFFFFF), .32)! : p.brand);
    final action = p.action;
    final background = dark ? p.darkBackground : p.lightBackground;
    final surface = p.id == 'folego'
        ? (dark ? const Color(0xFF1D1D24) : const Color(0xFFFFFFFF))
        : dark
            ? Color.lerp(background, const Color(0xFFFFFFFF), .075)!
            : Color.lerp(background, const Color(0xFFFFFFFF), .74)!;
    final brand = _ensureTextContrast(originalBrand, surface, background, dark);
    final onBrand = _onColor(brand);
    final high = p.id == 'folego'
        ? (dark ? const Color(0xFF25252D) : const Color(0xFFF0ECE2))
        : dark
            ? Color.lerp(background, const Color(0xFFFFFFFF), .14)!
            : Color.lerp(background, p.brand, .035)!;
    final primaryText = p.id == 'folego'
        ? (dark ? const Color(0xFFF0EFEA) : const Color(0xFF16150F))
        : (dark ? const Color(0xFFF4F2F5) : const Color(0xFF17151D));
    final secondaryText = p.id == 'folego'
        ? (dark ? const Color(0xFFB8B3C3) : const Color(0xFF6B6656))
        : (dark ? const Color(0xFFC4BEC9) : const Color(0xFF605A66));
    final border = p.id == 'folego'
        ? (dark ? const Color(0xFF2E2E38) : const Color(0xFFE4DFD2))
        : dark
            ? Color.lerp(background, const Color(0xFFFFFFFF), .22)!
            : Color.lerp(background, const Color(0xFF17151D), .16)!;
    // A marca de interface é acessível sobre o fundo, mas o hero usa uma
    // superfície de marca mais profunda para manter legíveis os estados suaves.
    final hero = p.id == 'folego'
        ? (dark ? const Color(0xFF54309F) : const Color(0xFF6C3CE9))
        : Color.lerp(p.brand, const Color(0xFF17101F), dark ? .62 : .49)!;
    const stateFolgaLight = Color(0xFF356516);
    const stateFolgaDark = Color(0xFFB4EC87);
    const stateApertadoLight = Color(0xFF915514);
    const stateApertadoDark = Color(0xFFFFCD82);
    const stateEstouradoLight = Color(0xFFA43D45);
    const stateEstouradoDark = Color(0xFFFFACA9);

    return FolegoColorTokens(
      marca: brand,
      marcaSobre: onBrand,
      marcaHero: hero,
      marcaHeroSobre: _onColor(hero),
      acao: action,
      acaoSobre: _onColor(action),
      fundo: background,
      superficie: surface,
      superficieAlta: high,
      textoPrincipal: primaryText,
      textoSecundario: secondaryText,
      borda: border,
      folga: dark ? stateFolgaDark : stateFolgaLight,
      folgaSobre: dark ? background : const Color(0xFFFFFFFF),
      apertado: dark ? stateApertadoDark : stateApertadoLight,
      apertadoSobre: dark ? background : const Color(0xFFFFFFFF),
      estourado: dark ? stateEstouradoDark : stateEstouradoLight,
      estouradoSobre: dark ? background : const Color(0xFFFFFFFF),
      folgaHero: p.id == 'folego'
          ? const Color(0xFFC6F135)
          : const Color(0xFFBAF095),
      apertadoHero: const Color(0xFFFFD18C),
      estouradoHero: const Color(0xFFFFB6B0),
    );
  }

  /// Marca usada como texto/ícone precisa alcançar 4.5:1 nas superfícies.
  /// A cor de referência e a cor do card principal permanecem independentes.
  static Color _ensureTextContrast(
    Color initial,
    Color surface,
    Color background,
    bool dark,
  ) {
    if (contrastRatio(initial, surface) >= 4.5 &&
        contrastRatio(initial, background) >= 4.5) {
      return initial;
    }
    final target = dark ? const Color(0xFFFFFFFF) : const Color(0xFF17151D);
    for (var step = 1; step <= 20; step++) {
      final candidate = Color.lerp(initial, target, step / 20)!;
      if (contrastRatio(candidate, surface) >= 4.5 &&
          contrastRatio(candidate, background) >= 4.5) {
        return candidate;
      }
    }
    return target;
  }

  static Color _onColor(Color background) =>
      contrastRatio(background, const Color(0xFF17151D)) >= 4.5
          ? const Color(0xFF17151D)
          : const Color(0xFFFFFFFF);

  static double contrastRatio(Color a, Color b) {
    double luminance(Color value) => value.computeLuminance();
    final first = luminance(a);
    final second = luminance(b);
    final light = first > second ? first : second;
    final dark = first > second ? second : first;
    return (light + .05) / (dark + .05);
  }

  static FolegoColorTokens of(BuildContext context) =>
      Theme.of(context).extension<FolegoColorTokens>() ??
      fromId('folego', Theme.of(context).brightness);

  @override
  FolegoColorTokens copyWith({
    Color? marca, Color? marcaSobre, Color? marcaHero, Color? marcaHeroSobre,
    Color? acao, Color? acaoSobre, Color? fundo, Color? superficie,
    Color? superficieAlta, Color? textoPrincipal, Color? textoSecundario,
    Color? borda, Color? folga, Color? folgaSobre, Color? apertado,
    Color? apertadoSobre, Color? estourado, Color? estouradoSobre,
    Color? folgaHero, Color? apertadoHero, Color? estouradoHero,
  }) => FolegoColorTokens(
    marca: marca ?? this.marca,
    marcaSobre: marcaSobre ?? this.marcaSobre,
    marcaHero: marcaHero ?? this.marcaHero,
    marcaHeroSobre: marcaHeroSobre ?? this.marcaHeroSobre,
    acao: acao ?? this.acao,
    acaoSobre: acaoSobre ?? this.acaoSobre,
    fundo: fundo ?? this.fundo,
    superficie: superficie ?? this.superficie,
    superficieAlta: superficieAlta ?? this.superficieAlta,
    textoPrincipal: textoPrincipal ?? this.textoPrincipal,
    textoSecundario: textoSecundario ?? this.textoSecundario,
    borda: borda ?? this.borda,
    folga: folga ?? this.folga,
    folgaSobre: folgaSobre ?? this.folgaSobre,
    apertado: apertado ?? this.apertado,
    apertadoSobre: apertadoSobre ?? this.apertadoSobre,
    estourado: estourado ?? this.estourado,
    estouradoSobre: estouradoSobre ?? this.estouradoSobre,
    folgaHero: folgaHero ?? this.folgaHero,
    apertadoHero: apertadoHero ?? this.apertadoHero,
    estouradoHero: estouradoHero ?? this.estouradoHero,
  );

  @override
  FolegoColorTokens lerp(ThemeExtension<FolegoColorTokens>? other, double t) {
    if (other is! FolegoColorTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FolegoColorTokens(
      marca: c(marca, other.marca), marcaSobre: c(marcaSobre, other.marcaSobre),
      marcaHero: c(marcaHero, other.marcaHero),
      marcaHeroSobre: c(marcaHeroSobre, other.marcaHeroSobre),
      acao: c(acao, other.acao), acaoSobre: c(acaoSobre, other.acaoSobre),
      fundo: c(fundo, other.fundo), superficie: c(superficie, other.superficie),
      superficieAlta: c(superficieAlta, other.superficieAlta),
      textoPrincipal: c(textoPrincipal, other.textoPrincipal),
      textoSecundario: c(textoSecundario, other.textoSecundario),
      borda: c(borda, other.borda), folga: c(folga, other.folga),
      folgaSobre: c(folgaSobre, other.folgaSobre),
      apertado: c(apertado, other.apertado),
      apertadoSobre: c(apertadoSobre, other.apertadoSobre),
      estourado: c(estourado, other.estourado),
      estouradoSobre: c(estouradoSobre, other.estouradoSobre),
      folgaHero: c(folgaHero, other.folgaHero),
      apertadoHero: c(apertadoHero, other.apertadoHero),
      estouradoHero: c(estouradoHero, other.estouradoHero),
    );
  }
}

@immutable
class FolegoPalette {
  const FolegoPalette(
    this.id, this.name, this.brand, this.action,
    this.lightBackground, this.darkBackground,
  );
  final String id, name;
  final Color brand, action, lightBackground, darkBackground;
}

/// Seleção local, compartilhada pela ThemeExtension e por widgets legados.
abstract final class AppColorSelection {
  static final ValueNotifier<String> selected = ValueNotifier<String>('folego');

  static void choose(String id) {
    selected.value = FolegoColorTokens.palette(id).id;
  }
}

/// Compatibilidade cromática de categorias e gráficos: valores imutáveis
/// centralizados aqui, fora dos widgets. Migração sem mudança visual.
abstract final class FolegoLegacyColors {
  static const transparent = Color(0x00000000);
  static const hexFF6C3CE9 = Color(0xFF6C3CE9);
  static const hexFF967CF4 = Color(0xFF967CF4);
  static const hexFFC6F135 = Color(0xFFC6F135);
  static const hexFFF5F1E8 = Color(0xFFF5F1E8);
  static const hexFFFFFFFF = Color(0xFFFFFFFF);
  static const hexFFE4DFD2 = Color(0xFFE4DFD2);
  static const hexFF16150F = Color(0xFF16150F);
  static const hexFF6B6656 = Color(0xFF6B6656);
  static const hexFF101014 = Color(0xFF101014);
  static const hexFF1D1D24 = Color(0xFF1D1D24);
  static const hexFF2E2E38 = Color(0xFF2E2E38);
  static const hexFFF0EFEA = Color(0xFFF0EFEA);
  static const hexFF9B98A8 = Color(0xFF9B98A8);
  static const hexFF3B6D11 = Color(0xFF3B6D11);
  static const hexFFEAF3DE = Color(0xFFEAF3DE);
  static const hexFFA9DB6B = Color(0xFFA9DB6B);
  static const hexFF712B13 = Color(0xFF712B13);
  static const hexFFFAECE7 = Color(0xFFFAECE7);
  static const hexFFF0A98A = Color(0xFFF0A98A);
  static const hexFFB39CF5 = Color(0xFFB39CF5);
  static const hexFFD4457A = Color(0xFFD4457A);
  static const hexFFF096B8 = Color(0xFFF096B8);
  static const hexFF993C1D = Color(0xFF993C1D);
  static const hexFFE8A87C = Color(0xFFE8A87C);
  static const hexFFFBEAF0 = Color(0xFFFBEAF0);
  static const hexFF993556 = Color(0xFF993556);
  static const hexFF3A2530 = Color(0xFF3A2530);
  static const hexFF22301A = Color(0xFF22301A);
  static const hexFF58A8A0 = Color(0xFF58A8A0);
  static const hexFF5969C9 = Color(0xFF5969C9);
  static const hexFFF0ECE2 = Color(0xFFF0ECE2);
  static const hexFF25252D = Color(0xFF25252D);
  static const hexFF9B7BFF = Color(0xFF9B7BFF);
  static const hexFF53B9FF = Color(0xFF53B9FF);
  static const hexFF1774B8 = Color(0xFF1774B8);
  static const hexFFFF62B0 = Color(0xFFFF62B0);
  static const hexFFFFD84D = Color(0xFFFFD84D);
  static const hexFF9A6A00 = Color(0xFF9A6A00);
  static const hexFFFF9F43 = Color(0xFFFF9F43);
  static const hexFFB35A00 = Color(0xFFB35A00);
  static const hexFFFF6B6B = Color(0xFFFF6B6B);
  static const hexFFB33A3A = Color(0xFFB33A3A);
  static const hexFF7C8CFF = Color(0xFF7C8CFF);
  static const hexFF4A57C8 = Color(0xFF4A57C8);
  static const hexFF4DE1C1 = Color(0xFF4DE1C1);
  static const hexFF16816D = Color(0xFF16816D);
  static const hexFFC96BFF = Color(0xFFC96BFF);
  static const hexFF8242B5 = Color(0xFF8242B5);
  static const hexFF6FE7A1 = Color(0xFF6FE7A1);
  static const hexFF2C8B55 = Color(0xFF2C8B55);
  static const hexFFFF8A70 = Color(0xFFFF8A70);
  static const hexFFB84F3B = Color(0xFFB84F3B);
  static const hexFFFF7A9C = Color(0xFFFF7A9C);
  static const hexFFB93E66 = Color(0xFFB93E66);
  static const hexFF5E7F14 = Color(0xFF5E7F14);
  static const hexFF5DDCFF = Color(0xFF5DDCFF);
  static const hexFF247B95 = Color(0xFF247B95);
  static const hexFF4FEAFF = Color(0xFF4FEAFF);
  static const hexFF167D91 = Color(0xFF167D91);
  static const hexFFB79CFF = Color(0xFFB79CFF);
  static const hexFF7054B8 = Color(0xFF7054B8);
  static const hexFFB5B2C0 = Color(0xFFB5B2C0);
  static const hexFF706B7A = Color(0xFF706B7A);
  static const hexFF8A6CF0 = Color(0xFF8A6CF0);
  static const hexFF35D6FF = Color(0xFF35D6FF);
  static const hexFFFF6B7A = Color(0xFFFF6B7A);
  static const hexFFFF69C9 = Color(0xFFFF69C9);
  static const hexFF45E0B7 = Color(0xFF45E0B7);
  static const hexFFB78CFF = Color(0xFFB78CFF);
  static const hexFF8B8A94 = Color(0xFF8B8A94);
  static const hexFFA8A7B2 = Color(0xFFA8A7B2);
}
