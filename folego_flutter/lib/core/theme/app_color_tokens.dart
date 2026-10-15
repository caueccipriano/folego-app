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
    final brand = p.id == 'folego'
        ? (dark ? const Color(0xFF967CF4) : p.brand)
        : (dark ? Color.lerp(p.brand, const Color(0xFFFFFFFF), .32)! : p.brand);
    final onBrand = _onColor(brand);
    final action = p.action;
    final background = dark ? p.darkBackground : p.lightBackground;
    final surface = dark
        ? Color.lerp(background, const Color(0xFFFFFFFF), .075)!
        : Color.lerp(background, const Color(0xFFFFFFFF), .74)!;
    final high = dark
        ? Color.lerp(background, const Color(0xFFFFFFFF), .14)!
        : Color.lerp(background, p.brand, .035)!;
    final primaryText = dark ? const Color(0xFFF4F2F5) : const Color(0xFF17151D);
    final secondaryText = dark ? const Color(0xFFC4BEC9) : const Color(0xFF605A66);
    final border = dark
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
