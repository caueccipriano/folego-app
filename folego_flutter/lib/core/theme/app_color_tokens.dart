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
    required this.acaoHero,
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
  final Color acao, acaoSobre, acaoHero;
  final Color fundo, superficie, superficieAlta;
  final Color textoPrincipal, textoSecundario, borda;
  final Color folga, folgaSobre, apertado, apertadoSobre;
  final Color estourado, estouradoSobre;
  final Color folgaHero, apertadoHero, estouradoHero;

  static const catalog = <FolegoPalette>[
    FolegoPalette('prisma_pastel', 'Prisma Pastel', Color(0xFF704A9C),
        Color(0xFFBCE8CF), Color(0xFFFCFAFF), Color(0xFF191321),
        description: 'Lavanda · menta · pêssego · rosa · azul'),
    FolegoPalette('after_dark', 'After Dark', Color(0xFF22405C),
        Color(0xFFB4FF62), Color(0xFFF0F4F8), Color(0xFF0C1020),
        description: 'Noturno · lima neon · turquesa'),
    FolegoPalette('ink', 'Ink', Color(0xFF222222),
        Color(0xFFDADAD6), Color(0xFFFAF8F3), Color(0xFF101113),
        description: 'Monocromático · clean · editorial'),
    FolegoPalette('velvet_berry', 'Velvet Berry', Color(0xFF63234D),
        Color(0xFFEEA6C7), Color(0xFFFFF8F7), Color(0xFF170D1B),
        description: 'Ameixa · framboesa · rosa'),
    FolegoPalette('hyperblue', 'Hyperblue', Color(0xFF315EE8),
        Color(0xFF78A5FF), Color(0xFFEEF3FF), Color(0xFF101A39),
        description: 'Azul-elétrico · digital · preciso'),
    FolegoPalette('solar_pop', 'Solar Pop', Color(0xFFA94517),
        Color(0xFFFFCE3A), Color(0xFFFFF1CC), Color(0xFF24160F),
        description: 'Laranja · amarelo · energia'),
  ];

  // Cada tema tem duas superfícies cuidadosamente desenhadas: claro e escuro.
  static const _colorways = <String, List<FolegoColorWay>>{
    'prisma_pastel': [
      FolegoColorWay(
        brand: Color(0xFF674498),
        background: Color(0xFFFCFAFF),
        surface: Color(0xFFFFFFFF),
        elevated: Color(0xFFF1E8F8),
        foreground: Color(0xFF242036),
        muted: Color(0xFF655975),
        border: Color(0xFFE5DBED),
        hero: Color(0xFFE8D8F8)),
      FolegoColorWay(
        brand: Color(0xFFD2B2FF),
        background: Color(0xFF191321),
        surface: Color(0xFF2B2035),
        elevated: Color(0xFF382944),
        foreground: Color(0xFFFBF5FF),
        muted: Color(0xFFD6C4E2),
        border: Color(0xFF4E3A59),
        hero: Color(0xFF382849)),
    ],
    'after_dark': [
      FolegoColorWay(
        brand: Color(0xFF24445C),
        background: Color(0xFFF0F4F8),
        surface: Color(0xFFFFFFFF),
        elevated: Color(0xFFE5EDF3),
        foreground: Color(0xFF172638),
        muted: Color(0xFF526879),
        border: Color(0xFFC9D7E1),
        hero: Color(0xFF182A40)),
      FolegoColorWay(
        brand: Color(0xFFC9FF77),
        background: Color(0xFF0C1020),
        surface: Color(0xFF1B2440),
        elevated: Color(0xFF273251),
        foreground: Color(0xFFF3F6FF),
        muted: Color(0xFFC3CDE4),
        border: Color(0xFF394765),
        hero: Color(0xFF203349)),
    ],
    'ink': [
      FolegoColorWay(
        brand: Color(0xFF222222),
        background: Color(0xFFFAF8F3),
        surface: Color(0xFFFFFFFF),
        elevated: Color(0xFFF0EFEB),
        foreground: Color(0xFF222222),
        muted: Color(0xFF5B5B57),
        border: Color(0xFFD4D4CF),
        hero: Color(0xFF303030)),
      FolegoColorWay(
        brand: Color(0xFFE4E4E1),
        background: Color(0xFF101113),
        surface: Color(0xFF212124),
        elevated: Color(0xFF313136),
        foreground: Color(0xFFF9F9F7),
        muted: Color(0xFFC7C7C4),
        border: Color(0xFF444449),
        hero: Color(0xFF2C2C30)),
    ],
    'velvet_berry': [
      FolegoColorWay(
        brand: Color(0xFF63234D),
        background: Color(0xFFFFF8F7),
        surface: Color(0xFFFFFFFF),
        elevated: Color(0xFFF5E6ED),
        foreground: Color(0xFF311F2D),
        muted: Color(0xFF705869),
        border: Color(0xFFEBD0DC),
        hero: Color(0xFF63234D)),
      FolegoColorWay(
        brand: Color(0xFFFFA6CF),
        background: Color(0xFF170D1B),
        surface: Color(0xFF2B1A32),
        elevated: Color(0xFF3D2945),
        foreground: Color(0xFFFFEFF7),
        muted: Color(0xFFD7BDD6),
        border: Color(0xFF5E4164),
        hero: Color(0xFF4C2344)),
    ],
    'hyperblue': [
      FolegoColorWay(
        brand: Color(0xFF315EE8),
        background: Color(0xFFEEF3FF),
        surface: Color(0xFFFFFFFF),
        elevated: Color(0xFFDFE9FF),
        foreground: Color(0xFF19294A),
        muted: Color(0xFF51627F),
        border: Color(0xFFC8D8F8),
        hero: Color(0xFF315EE8)),
      FolegoColorWay(
        brand: Color(0xFFA1C0FF),
        background: Color(0xFF101A39),
        surface: Color(0xFF1A2949),
        elevated: Color(0xFF2B3C63),
        foreground: Color(0xFFF1F5FF),
        muted: Color(0xFFC0CDEA),
        border: Color(0xFF40547D),
        hero: Color(0xFF233A84)),
    ],
    'solar_pop': [
      FolegoColorWay(
        brand: Color(0xFFA94517),
        background: Color(0xFFFFF1CC),
        surface: Color(0xFFFFFBF0),
        elevated: Color(0xFFFFE4B3),
        foreground: Color(0xFF442817),
        muted: Color(0xFF795A3C),
        border: Color(0xFFF2D49A),
        hero: Color(0xFFC64C22)),
      FolegoColorWay(
        brand: Color(0xFFFFB784),
        background: Color(0xFF24160F),
        surface: Color(0xFF382319),
        elevated: Color(0xFF4B3123),
        foreground: Color(0xFFFFF2DE),
        muted: Color(0xFFDEC4A6),
        border: Color(0xFF684631),
        hero: Color(0xFF783719)),
    ],
  };

  // Preferências salvas de versões anteriores são migradas sem perder o modo de exibição.
  static const _legacyPaletteIds = <String, String>{
    'fluxo': 'ink',
    'folego': 'prisma_pastel',
    'pistache_frost': 'prisma_pastel',
    'terracota_gallery': 'solar_pop',
    'mare': 'prisma_pastel',
    'salvia': 'prisma_pastel',
    'chiclete': 'velvet_berry',
    'tangerina': 'solar_pop',
    'neon': 'after_dark',
    'safira': 'hyperblue',
    'mochi': 'prisma_pastel',
    'cacau': 'solar_pop',
    'matcha': 'prisma_pastel',
    'pixel': 'hyperblue',
    'cherry': 'velvet_berry',
    'butter': 'solar_pop',
    'orbit': 'after_dark',
    'disco': 'velvet_berry',
    'terracota': 'solar_pop',
    'indigopop': 'velvet_berry',
    'oldlace': 'ink',
    'discofever': 'after_dark',
    'bruma': 'ink',
    'jet': 'ink',
    'acidblue': 'hyperblue',
    'popart': 'solar_pop',
    'forestclub': 'solar_pop',
  };

  /// Cores decorativas das miniaturas. Não substituem estados financeiros.
  static List<Color> previewAccents(String id, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (palette(id).id) {
      case 'prisma_pastel':
        return dark
            ? const [Color(0xFFCAADFF), Color(0xFF9DDBBE), Color(0xFFFFCD9D), Color(0xFFF4AFCB), Color(0xFF9DD1F5)]
            : const [Color(0xFFB49AEF), Color(0xFFBCE8CF), Color(0xFFFFD6A0), Color(0xFFF4AFCB), Color(0xFFA9D7F5)];
      case 'after_dark':
        return const [Color(0xFF1B2440), Color(0xFFB4FF62), Color(0xFF5BE3DF)];
      case 'ink':
        return const [Color(0xFF222222), Color(0xFF999995), Color(0xFFE1E1DD)];
      case 'velvet_berry':
        return const [Color(0xFF63234D), Color(0xFFDB5B91), Color(0xFFEEC1D3)];
      case 'hyperblue':
        return const [Color(0xFF315EE8), Color(0xFF78A5FF), Color(0xFF17294B)];
      case 'solar_pop':
        return const [Color(0xFFFF6D35), Color(0xFFFFCE3A), Color(0xFF452815)];
    }
    return const [Color(0xFFB49AEF)];
  }

  static FolegoPalette palette(String id) {
    final resolved = _legacyPaletteIds[id] ?? id;
    return catalog.firstWhere((item) => item.id == resolved,
        orElse: () => catalog.first);
  }

  static FolegoColorTokens fromId(String id, Brightness brightness) {
    final p = palette(id);
    final dark = brightness == Brightness.dark;
    final way = _colorways[p.id]![dark ? 1 : 0];
    final brand = _ensureTextContrast(
      way.brand, way.surface, way.background, dark,
    );
    final primary = _ensureTextContrast(
      way.foreground, way.surface, way.background, dark,
    );
    // Muted labels must still be legible; "secondary" means less emphasis,
    // not less than WCAG AA text contrast on normal card surfaces.
    final secondary = _ensureTextContrast(
      way.muted, way.surface, way.background, dark,
    );
    // Cores financeiras semânticas NÃO seguem a paleta: o mesmo estado
    // (folga, atenção e déficit) precisa ter o mesmo significado em todas.
    const stateFolgaLight = Color(0xFF356516);
    const stateFolgaDark = Color(0xFFB4EC87);
    const stateApertadoLight = Color(0xFF915514);
    const stateApertadoDark = Color(0xFFFFCD82);
    const stateEstouradoLight = Color(0xFFA43D45);
    const stateEstouradoDark = Color(0xFFFFACA9);

    return FolegoColorTokens(
      marca: brand,
      marcaSobre: _onColor(brand),
      marcaHero: way.hero,
      marcaHeroSobre: _onColor(way.hero),
      acao: p.action,
      acaoSobre: _onColor(p.action),
      acaoHero: _accentOnHero(p.action, way.hero),
      fundo: way.background,
      superficie: way.surface,
      superficieAlta: way.elevated,
      textoPrincipal: primary,
      textoSecundario: secondary,
      borda: way.border,
      folga: dark ? stateFolgaDark : stateFolgaLight,
      folgaSobre: dark ? way.background : const Color(0xFFFFFFFF),
      apertado: dark ? stateApertadoDark : stateApertadoLight,
      apertadoSobre: dark ? way.background : const Color(0xFFFFFFFF),
      estourado: dark ? stateEstouradoDark : stateEstouradoLight,
      estouradoSobre: dark ? way.background : const Color(0xFFFFFFFF),
      // Hero accents adapt to the actual hero surface; pastel cards cannot
      // use pale-on-pale text. Preserve green/amber/red meaning across themes.
      folgaHero: _ensureTextContrast(
        const Color(0xFFBAF095), way.hero, way.hero, dark),
      apertadoHero: _ensureTextContrast(
        const Color(0xFFFFD18C), way.hero, way.hero, dark),
      estouradoHero: _ensureTextContrast(
        const Color(0xFFFFB6B0), way.hero, way.hero, dark),
    );
  }

  /// Realce numérico secundário sobre o hero. Mantém o matiz de [acao]
  /// e clareia só o necessário para WCAG AA (4.5:1 em texto comum).
  /// A cor original de botões/ações permanece inalterada.
  static Color _accentOnHero(Color action, Color hero) {
    if (contrastRatio(action, hero) >= 4.5) return action;
    const dark = Color(0xFF17151D);
    const white = Color(0xFFFFFFFF);
    // A light hero cannot be fixed by whitening the accent; choose the
    // direction that actually increases contrast while keeping the hue
    // whenever possible.
    final target = contrastRatio(dark, hero) >= contrastRatio(white, hero)
        ? dark : white;
    for (var step = 1; step <= 20; step++) {
      final candidate = Color.lerp(action, target, step / 20)!;
      if (contrastRatio(candidate, hero) >= 4.5) return candidate;
    }
    return target;
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
      fromId('prisma_pastel', Theme.of(context).brightness);

  @override
  FolegoColorTokens copyWith({
    Color? marca, Color? marcaSobre, Color? marcaHero, Color? marcaHeroSobre,
    Color? acao, Color? acaoSobre, Color? acaoHero, Color? fundo, Color? superficie,
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
    acaoHero: acaoHero ?? this.acaoHero,
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
      acaoHero: c(acaoHero, other.acaoHero),
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
    this.id,
    this.name,
    this.brand,
    this.action,
    this.lightBackground,
    this.darkBackground, {
    this.description = '',
  });
  final String id, name;
  final Color brand, action, lightBackground, darkBackground;
  final String description;
}

@immutable
class FolegoColorWay {
  const FolegoColorWay({
    required this.brand,
    required this.background,
    required this.surface,
    required this.elevated,
    required this.foreground,
    required this.muted,
    required this.border,
    required this.hero,
  });

  final Color brand, background, surface, elevated;
  final Color foreground, muted, border, hero;
}

/// Seleção local, compartilhada pela ThemeExtension e por widgets legados.
abstract final class AppColorSelection {
  static final ValueNotifier<String> selected = ValueNotifier<String>('prisma_pastel');

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
