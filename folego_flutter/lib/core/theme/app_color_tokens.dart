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
    FolegoPalette('folego', 'Fôlego', Color(0xFF6C3CE9),
        Color(0xFFC6F135), Color(0xFFF5F1E8), Color(0xFF101014),
        description: 'Roxo + lima · original'),
    FolegoPalette('pistache_frost', 'Pistache Frost', Color(0xFF5798D7),
        Color(0xFFB9C255), Color(0xFFE6F1FA), Color(0xFF0D1B27),
        description: 'Pistache + azul-gelo'),
    FolegoPalette('terracota_gallery', 'Terracota Gallery', Color(0xFFC34811),
        Color(0xFFD9D1CA), Color(0xFFF6F2ED), Color(0xFF181820),
        description: 'Terracota + azul-galeria + linho'),
    FolegoPalette('mare', 'Maré', Color(0xFF0F8B8D),
        Color(0xFFFF7A59), Color(0xFFEDF8F8), Color(0xFF091A1C),
        description: 'Turquesa + coral'),
    FolegoPalette('salvia', 'Sálvia', Color(0xFF5F8F6B),
        Color(0xFFFFB88A), Color(0xFFF4F8F0), Color(0xFF121E16),
        description: 'Verde + damasco'),
    FolegoPalette('chiclete', 'Chiclete', Color(0xFFE0488F),
        Color(0xFF7CD7FF), Color(0xFFFFF1F8), Color(0xFF1B0D18),
        description: 'Rosa + azul-gelo'),
    FolegoPalette('tangerina', 'Tangerina', Color(0xFFF26B1D),
        Color(0xFFFFD23F), Color(0xFFFFF6E9), Color(0xFF21150C),
        description: 'Laranja + mel'),
    FolegoPalette('neon', 'Neon', Color(0xFF2B3040),
        Color(0xFF19E0F0), Color(0xFFF1F6FA), Color(0xFF080F18),
        description: 'Grafite + ciano'),
    FolegoPalette('safira', 'Safira', Color(0xFF234EC4),
        Color(0xFF71EDC3), Color(0xFFF2F5FF), Color(0xFF0D1427),
        description: 'Azul + menta'),
    FolegoPalette('mochi', 'Mochi', Color(0xFF7649A4),
        Color(0xFFFFB68A), Color(0xFFFBF3FF), Color(0xFF1C1225),
        description: 'Lavanda + pêssego'),
    FolegoPalette('cacau', 'Cacau', Color(0xFF76533B),
        Color(0xFFC5F18C), Color(0xFFFAF5ED), Color(0xFF201A16),
        description: 'Café + pistache'),
    FolegoPalette('matcha', 'Matcha', Color(0xFF376A42),
        Color(0xFFFFD97D), Color(0xFFF3F7E7), Color(0xFF111B13),
        description: 'Verde matcha + manteiga'),
    FolegoPalette('pixel', 'Pixel', Color(0xFF2453C8),
        Color(0xFFFFDC42), Color(0xFFF4F7FF), Color(0xFF0B1030),
        description: 'Azul digital + amarelo'),
    FolegoPalette('cherry', 'Cherry Cola', Color(0xFF803046),
        Color(0xFFFFE5B0), Color(0xFFFBF3EF), Color(0xFF1F1118),
        description: 'Cereja escura + baunilha'),
    FolegoPalette('butter', 'Butter', Color(0xFF785A18),
        Color(0xFF8DBAFF), Color(0xFFFFF9E9), Color(0xFF1E190F),
        description: 'Amarelo-manteiga + azul'),
    FolegoPalette('orbit', 'Órbita', Color(0xFF24566E),
        Color(0xFFE2FC83), Color(0xFFEFF3F5), Color(0xFF0A151B),
        description: 'Petróleo + lima suave'),
    FolegoPalette('disco', 'Disco', Color(0xFFA72F8D),
        Color(0xFFB8FF5F), Color(0xFFFFF1FC), Color(0xFF1C0F1E),
        description: 'Magenta + verde ácido'),
    FolegoPalette('terracota', 'Terracota', Color(0xFFA64526),
        Color(0xFFB6A460), Color(0xFFF9F0E4), Color(0xFF231714),
        description: 'Terracota + oliva'),
    FolegoPalette('indigopop', 'Índigo Pop', Color(0xFF4D166C),
        Color(0xFFF94500), Color(0xFFFBF8E9), Color(0xFF180C23),
        description: 'Índigo + laranja vivo'),
    FolegoPalette('oldlace', 'Old Lace', Color(0xFF2E51A1),
        Color(0xFFF34F37), Color(0xFFFAF7EC), Color(0xFF111924),
        description: 'Azul retrô + tomate'),
    FolegoPalette('discofever', 'Disco Fever', Color(0xFF6423CD),
        Color(0xFFE9FF3D), Color(0xFFF7F2FF), Color(0xFF1A0F2E),
        description: 'Violeta + lima neon'),
    FolegoPalette('bruma', 'Bruma', Color(0xFF224A5E),
        Color(0xFFE8B35E), Color(0xFFF1F4F1), Color(0xFF121E25),
        description: 'Azul-petróleo + areia'),
    FolegoPalette('jet', 'Jet', Color(0xFF333D44),
        Color(0xFFF2BA36), Color(0xFFF3F2ED), Color(0xFF15181B),
        description: 'Grafite + mostarda'),
    FolegoPalette('acidblue', 'Acid Blue', Color(0xFF284BE0),
        Color(0xFFCBF548), Color(0xFFF4F9EB), Color(0xFF0D1740),
        description: 'Azul elétrico + lima'),
    FolegoPalette('popart', 'Pop Art', Color(0xFF483183),
        Color(0xFFF5ED69), Color(0xFFFFFDEC), Color(0xFF19142D),
        description: 'Roxo + amarelo solar'),
    FolegoPalette('forestclub', 'Forest Club', Color(0xFF2A6543),
        Color(0xFFF5BB5F), Color(0xFFFBF2E1), Color(0xFF14231C),
        description: 'Floresta + mel'),
    FolegoPalette('hyperblue', 'Hyper Blue', Color(0xFF284BDF),
        Color(0xFFFF8A37), Color(0xFFFAF4E8), Color(0xFF101A39),
        description: 'Azul intenso + tangerina'),
  ];

  // Cada paleta tem cores próprias para claro e escuro. Não interpolar
  // superfícies com branco/preto nem misturar tons de duas paletas.
  static const _colorways = <String, List<FolegoColorWay>>{
    'folego': [
      FolegoColorWay(brand: Color(0xFF6C3CE9), background: Color(0xFFF5F1E8),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFF0ECE2),
        foreground: Color(0xFF16150F), muted: Color(0xFF6B6656),
        border: Color(0xFFE4DFD2), hero: Color(0xFF6C3CE9)),
      FolegoColorWay(brand: Color(0xFF967CF4), background: Color(0xFF101014),
        surface: Color(0xFF1D1D24), elevated: Color(0xFF25252D),
        foreground: Color(0xFFF0EFEA), muted: Color(0xFFB8B3C3),
        border: Color(0xFF2E2E38), hero: Color(0xFF54309F)),
    ],
    'mare': [
      FolegoColorWay(brand: Color(0xFF086A6D), background: Color(0xFFEDF8F8),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFDFF0EF),
        foreground: Color(0xFF142B2C), muted: Color(0xFF536C70),
        border: Color(0xFFCBE5E4), hero: Color(0xFF0F6465)),
      FolegoColorWay(brand: Color(0xFF63D4CE), background: Color(0xFF091A1C),
        surface: Color(0xFF14282A), elevated: Color(0xFF1C3537),
        foreground: Color(0xFFE6F6F5), muted: Color(0xFFA7CBCA),
        border: Color(0xFF2C4B4D), hero: Color(0xFF104143)),
    ],
    'salvia': [
      FolegoColorWay(brand: Color(0xFF3F6E49), background: Color(0xFFF4F8F0),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFE8F0E1),
        foreground: Color(0xFF1B2C22), muted: Color(0xFF526B5A),
        border: Color(0xFFD9E4D3), hero: Color(0xFF345B3D)),
      FolegoColorWay(brand: Color(0xFFA3D6A8), background: Color(0xFF121E16),
        surface: Color(0xFF1B2C21), elevated: Color(0xFF28392B),
        foreground: Color(0xFFEBF5E9), muted: Color(0xFFB5CDBA),
        border: Color(0xFF344D3A), hero: Color(0xFF2A5136)),
    ],
    'chiclete': [
      FolegoColorWay(brand: Color(0xFFB62C73), background: Color(0xFFFFF1F8),
        surface: Color(0xFFFFF9FC), elevated: Color(0xFFFFE3F2),
        foreground: Color(0xFF361628), muted: Color(0xFF7E4B68),
        border: Color(0xFFF2CADF), hero: Color(0xFF9A1F63)),
      FolegoColorWay(brand: Color(0xFFFF92C7), background: Color(0xFF1B0D18),
        surface: Color(0xFF2D1627), elevated: Color(0xFF412039),
        foreground: Color(0xFFFBEAF4), muted: Color(0xFFDBA6C4),
        border: Color(0xFF65314F), hero: Color(0xFF6D1748)),
    ],
    'tangerina': [
      FolegoColorWay(brand: Color(0xFFAC4B0A), background: Color(0xFFFFF6E9),
        surface: Color(0xFFFFFCF5), elevated: Color(0xFFFFEDD2),
        foreground: Color(0xFF392210), muted: Color(0xFF846342),
        border: Color(0xFFF0D8B8), hero: Color(0xFF87410E)),
      FolegoColorWay(brand: Color(0xFFFFAC74), background: Color(0xFF21150C),
        surface: Color(0xFF36231A), elevated: Color(0xFF493024),
        foreground: Color(0xFFFFF1E0), muted: Color(0xFFDABCA3),
        border: Color(0xFF6A4B36), hero: Color(0xFF743015)),
    ],
    'neon': [
      FolegoColorWay(brand: Color(0xFF2A4567), background: Color(0xFFF1F6FA),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFE4EBF2),
        foreground: Color(0xFF132137), muted: Color(0xFF526778),
        border: Color(0xFFCBD8E4), hero: Color(0xFF18384A)),
      FolegoColorWay(brand: Color(0xFF77CBF2), background: Color(0xFF080F18),
        surface: Color(0xFF141E2A), elevated: Color(0xFF1F2E3A),
        foreground: Color(0xFFEEF9FB), muted: Color(0xFFB1C5D0),
        border: Color(0xFF31434F), hero: Color(0xFF0D3341)),
    ],
    'safira': [
      FolegoColorWay(brand: Color(0xFF234EC4), background: Color(0xFFF2F5FF),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFE7EDFF),
        foreground: Color(0xFF17264A), muted: Color(0xFF5A6688),
        border: Color(0xFFCFD9F3), hero: Color(0xFF173B94)),
      FolegoColorWay(brand: Color(0xFF9BB9FF), background: Color(0xFF0D1427),
        surface: Color(0xFF18213A), elevated: Color(0xFF242F4B),
        foreground: Color(0xFFF1F5FF), muted: Color(0xFFB8C6EA),
        border: Color(0xFF37476C), hero: Color(0xFF213C86)),
    ],
    'mochi': [
      FolegoColorWay(brand: Color(0xFF7649A4), background: Color(0xFFFBF3FF),
        surface: Color(0xFFFFFBFF), elevated: Color(0xFFF1E6F8),
        foreground: Color(0xFF2D1A3B), muted: Color(0xFF796080),
        border: Color(0xFFE8D6EC), hero: Color(0xFF593277)),
      FolegoColorWay(brand: Color(0xFFCCA7FF), background: Color(0xFF1C1225),
        surface: Color(0xFF2B1D34), elevated: Color(0xFF3A2B44),
        foreground: Color(0xFFF9EFFF), muted: Color(0xFFCEB9DA),
        border: Color(0xFF554360), hero: Color(0xFF442553)),
    ],
    'cacau': [
      FolegoColorWay(brand: Color(0xFF76533B), background: Color(0xFFFAF5ED),
        surface: Color(0xFFFFFDF7), elevated: Color(0xFFEEE4D5),
        foreground: Color(0xFF32291E), muted: Color(0xFF71624F),
        border: Color(0xFFDFD3BF), hero: Color(0xFF583B2A)),
      FolegoColorWay(brand: Color(0xFFDDB78C), background: Color(0xFF201A16),
        surface: Color(0xFF30251E), elevated: Color(0xFF403226),
        foreground: Color(0xFFF8EFE2), muted: Color(0xFFCEBAA1),
        border: Color(0xFF61513F), hero: Color(0xFF4A2F22)),
    ],
    'matcha': [
      FolegoColorWay(brand: Color(0xFF376A42), background: Color(0xFFF3F7E7),
        surface: Color(0xFFFBFFF6), elevated: Color(0xFFE4EBD2),
        foreground: Color(0xFF203024), muted: Color(0xFF576B5A),
        border: Color(0xFFCFDCC0), hero: Color(0xFF365B39)),
      FolegoColorWay(brand: Color(0xFFA9D6A2), background: Color(0xFF111B13),
        surface: Color(0xFF1C2B1E), elevated: Color(0xFF2B402D),
        foreground: Color(0xFFEEF6EA), muted: Color(0xFFBACDBB),
        border: Color(0xFF38543D), hero: Color(0xFF274A2D)),
    ],
    'pixel': [
      FolegoColorWay(brand: Color(0xFF2453C8), background: Color(0xFFF4F7FF),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFE5EDFF),
        foreground: Color(0xFF1A2145), muted: Color(0xFF525E80),
        border: Color(0xFFD1DCF0), hero: Color(0xFF1640A4)),
      FolegoColorWay(brand: Color(0xFF9CB6FF), background: Color(0xFF0B1030),
        surface: Color(0xFF151E41), elevated: Color(0xFF223057),
        foreground: Color(0xFFF1F4FF), muted: Color(0xFFB7C5EA),
        border: Color(0xFF334777), hero: Color(0xFF163FAD)),
    ],
    'cherry': [
      FolegoColorWay(brand: Color(0xFF803046), background: Color(0xFFFBF3EF),
        surface: Color(0xFFFFFCF9), elevated: Color(0xFFF3E2DC),
        foreground: Color(0xFF3B2428), muted: Color(0xFF78595B),
        border: Color(0xFFE6CCC7), hero: Color(0xFF72283B)),
      FolegoColorWay(brand: Color(0xFFFFD0B4), background: Color(0xFF1F1118),
        surface: Color(0xFF301E26), elevated: Color(0xFF42272F),
        foreground: Color(0xFFFAEDF0), muted: Color(0xFFD3B7BD),
        border: Color(0xFF62434B), hero: Color(0xFF5D2333)),
    ],
    'butter': [
      FolegoColorWay(brand: Color(0xFF785A18), background: Color(0xFFFFF9E9),
        surface: Color(0xFFFFFEF8), elevated: Color(0xFFFFF0C9),
        foreground: Color(0xFF322A20), muted: Color(0xFF78654B),
        border: Color(0xFFEBDDAD), hero: Color(0xFF755110)),
      FolegoColorWay(brand: Color(0xFFFFE394), background: Color(0xFF1E190F),
        surface: Color(0xFF302819), elevated: Color(0xFF443923),
        foreground: Color(0xFFFFF7E4), muted: Color(0xFFD5C8A7),
        border: Color(0xFF625139), hero: Color(0xFF634711)),
    ],
    'orbit': [
      FolegoColorWay(brand: Color(0xFF24566E), background: Color(0xFFEFF3F5),
        surface: Color(0xFFFAFDFD), elevated: Color(0xFFDAE5EB),
        foreground: Color(0xFF1B313C), muted: Color(0xFF536F7B),
        border: Color(0xFFC7D6DF), hero: Color(0xFF20485D)),
      FolegoColorWay(brand: Color(0xFF92D7E5), background: Color(0xFF0A151B),
        surface: Color(0xFF17262F), elevated: Color(0xFF213A43),
        foreground: Color(0xFFE8F4F4), muted: Color(0xFFACC4CB),
        border: Color(0xFF34515D), hero: Color(0xFF143949)),
    ],
    'disco': [
      FolegoColorWay(brand: Color(0xFFA72F8D), background: Color(0xFFFFF1FC),
        surface: Color(0xFFFFFAFF), elevated: Color(0xFFF5E2F4),
        foreground: Color(0xFF3D1A35), muted: Color(0xFF795772),
        border: Color(0xFFEDC9E8), hero: Color(0xFF83256E)),
      FolegoColorWay(brand: Color(0xFFFF9EEB), background: Color(0xFF1C0F1E),
        surface: Color(0xFF301B32), elevated: Color(0xFF452647),
        foreground: Color(0xFFFFF0FC), muted: Color(0xFFD9B7D4),
        border: Color(0xFF67416A), hero: Color(0xFF692059)),
    ],
    'terracota': [
      FolegoColorWay(brand: Color(0xFFA64526), background: Color(0xFFF9F0E4),
        surface: Color(0xFFFFFAF3), elevated: Color(0xFFF0DFC7),
        foreground: Color(0xFF3A251C), muted: Color(0xFF775847),
        border: Color(0xFFE0CDB6), hero: Color(0xFFA94827)),
      FolegoColorWay(brand: Color(0xFFE7A879), background: Color(0xFF231714),
        surface: Color(0xFF34211B), elevated: Color(0xFF483024),
        foreground: Color(0xFFF9ECDD), muted: Color(0xFFD5B6A2),
        border: Color(0xFF655044), hero: Color(0xFF783A24)),
    ],
    'indigopop': [
      FolegoColorWay(brand: Color(0xFF4D166C), background: Color(0xFFFBF8E9),
        surface: Color(0xFFFFFFFF), elevated: Color(0xFFECE2F4),
        foreground: Color(0xFF24132D), muted: Color(0xFF715C7D),
        border: Color(0xFFDBCEE7), hero: Color(0xFF23003F)),
      FolegoColorWay(brand: Color(0xFFE7B3F1), background: Color(0xFF180C23),
        surface: Color(0xFF281235), elevated: Color(0xFF381C4D),
        foreground: Color(0xFFF8EFFD), muted: Color(0xFFD2BCDF),
        border: Color(0xFF55405E), hero: Color(0xFF341052)),
    ],
    'oldlace': [
      FolegoColorWay(brand: Color(0xFF2E51A1), background: Color(0xFFFAF7EC),
        surface: Color(0xFFFFFEF7), elevated: Color(0xFFE8EDE8),
        foreground: Color(0xFF1C2634), muted: Color(0xFF626A78),
        border: Color(0xFFD5D8CC), hero: Color(0xFF254579)),
      FolegoColorWay(brand: Color(0xFF9CC2FF), background: Color(0xFF111924),
        surface: Color(0xFF1D2B3A), elevated: Color(0xFF273C4E),
        foreground: Color(0xFFEEF5F2), muted: Color(0xFFB6C8D1),
        border: Color(0xFF3A5364), hero: Color(0xFF1A3B6C)),
    ],
    'discofever': [
      FolegoColorWay(brand: Color(0xFF6423CD), background: Color(0xFFF7F2FF),
        surface: Color(0xFFFFFBFF), elevated: Color(0xFFE9DFFF),
        foreground: Color(0xFF261444), muted: Color(0xFF69548A),
        border: Color(0xFFD7C7EF), hero: Color(0xFF5322A1)),
      FolegoColorWay(brand: Color(0xFFCEAFFD), background: Color(0xFF1A0F2E),
        surface: Color(0xFF2A1843), elevated: Color(0xFF3A235C),
        foreground: Color(0xFFF7EEFF), muted: Color(0xFFC9B9E1),
        border: Color(0xFF584575), hero: Color(0xFF43177A)),
    ],
    'bruma': [
      FolegoColorWay(brand: Color(0xFF224A5E), background: Color(0xFFF1F4F1),
        surface: Color(0xFFFCFDFC), elevated: Color(0xFFE3E8E5),
        foreground: Color(0xFF1D323A), muted: Color(0xFF526D74),
        border: Color(0xFFCDD7D4), hero: Color(0xFF21495B)),
      FolegoColorWay(brand: Color(0xFF9BCFDE), background: Color(0xFF121E25),
        surface: Color(0xFF1B303A), elevated: Color(0xFF26404A),
        foreground: Color(0xFFEAF4F1), muted: Color(0xFFB6CBC8),
        border: Color(0xFF375661), hero: Color(0xFF183B4B)),
    ],
    'jet': [
      FolegoColorWay(brand: Color(0xFF333D44), background: Color(0xFFF3F2ED),
        surface: Color(0xFFFEFDF7), elevated: Color(0xFFE5E5DF),
        foreground: Color(0xFF252B30), muted: Color(0xFF586167),
        border: Color(0xFFD1D5D5), hero: Color(0xFF283139)),
      FolegoColorWay(brand: Color(0xFFD5E1E3), background: Color(0xFF15181B),
        surface: Color(0xFF242A2E), elevated: Color(0xFF31383B),
        foreground: Color(0xFFEEF2F0), muted: Color(0xFFB9C3C0),
        border: Color(0xFF454E53), hero: Color(0xFF2B3237)),
    ],
    'acidblue': [
      FolegoColorWay(brand: Color(0xFF284BE0), background: Color(0xFFF4F9EB),
        surface: Color(0xFFFFFEFC), elevated: Color(0xFFE8F0D1),
        foreground: Color(0xFF1B2A4B), muted: Color(0xFF566987),
        border: Color(0xFFD0DCBC), hero: Color(0xFF2941B4)),
      FolegoColorWay(brand: Color(0xFF9AB7FF), background: Color(0xFF0D1740),
        surface: Color(0xFF182756), elevated: Color(0xFF263766),
        foreground: Color(0xFFEEF4FF), muted: Color(0xFFB6C8F2),
        border: Color(0xFF394F80), hero: Color(0xFF1A2F85)),
    ],
    'popart': [
      FolegoColorWay(brand: Color(0xFF483183), background: Color(0xFFFFFDEC),
        surface: Color(0xFFFFFFF8), elevated: Color(0xFFF1ECCA),
        foreground: Color(0xFF2B2345), muted: Color(0xFF736786),
        border: Color(0xFFE2D7BD), hero: Color(0xFF3D2B7C)),
      FolegoColorWay(brand: Color(0xFFC8B5FF), background: Color(0xFF19142D),
        surface: Color(0xFF272042), elevated: Color(0xFF372957),
        foreground: Color(0xFFF9F3FF), muted: Color(0xFFC6BBE4),
        border: Color(0xFF53466D), hero: Color(0xFF362670)),
    ],
    'forestclub': [
      FolegoColorWay(brand: Color(0xFF2A6543), background: Color(0xFFFBF2E1),
        surface: Color(0xFFFFF9ED), elevated: Color(0xFFE7E5C8),
        foreground: Color(0xFF22362A), muted: Color(0xFF5B6F51),
        border: Color(0xFFD7D7B4), hero: Color(0xFF28583B)),
      FolegoColorWay(brand: Color(0xFFB7DCB3), background: Color(0xFF14231C),
        surface: Color(0xFF203529), elevated: Color(0xFF2D4633),
        foreground: Color(0xFFF0F4E8), muted: Color(0xFFBFD1BE),
        border: Color(0xFF416048), hero: Color(0xFF1D4D33)),
    ],
    'hyperblue': [
      FolegoColorWay(brand: Color(0xFF284BDF), background: Color(0xFFFAF4E8),
        surface: Color(0xFFFFFDF8), elevated: Color(0xFFF0E2C9),
        foreground: Color(0xFF1B2A54), muted: Color(0xFF5B6689),
        border: Color(0xFFDCD1B7), hero: Color(0xFF2740B1)),
      FolegoColorWay(brand: Color(0xFFAEC2FF), background: Color(0xFF101A39),
        surface: Color(0xFF1B2B4F), elevated: Color(0xFF2A3C61),
        foreground: Color(0xFFF1F5FF), muted: Color(0xFFB7C6E7),
        border: Color(0xFF3A5178), hero: Color(0xFF203784)),
    ],
    'pistache_frost': [
      FolegoColorWay(brand: Color(0xFF5798D7), background: Color(0xFFE6F1FA),
        surface: Color(0xFFFDFEFF), elevated: Color(0xFFD5E8F6),
        foreground: Color(0xFF183649), muted: Color(0xFF526C7D),
        border: Color(0xFFC2D8E8), hero: Color(0xFF254A72)),
      FolegoColorWay(brand: Color(0xFF90C4F2), background: Color(0xFF0D1B27),
        surface: Color(0xFF172A3A), elevated: Color(0xFF243A4D),
        foreground: Color(0xFFEDF6FB), muted: Color(0xFFB9CDDA),
        border: Color(0xFF35526A), hero: Color(0xFF123B56)),
    ],
    'terracota_gallery': [
      FolegoColorWay(brand: Color(0xFFC34811), background: Color(0xFFF6F2ED),
        surface: Color(0xFFFFFDFB), elevated: Color(0xFFD9D1CA),
        foreground: Color(0xFF332824), muted: Color(0xFF736259),
        border: Color(0xFFD8C6BB), hero: Color(0xFF0B369A)),
      FolegoColorWay(brand: Color(0xFFFF9E79), background: Color(0xFF181820),
        surface: Color(0xFF252531), elevated: Color(0xFF37343D),
        foreground: Color(0xFFFAF3EE), muted: Color(0xFFCBBDB8),
        border: Color(0xFF514D58), hero: Color(0xFF1A4299)),
    ],
  };

  static FolegoPalette palette(String id) =>
      catalog.firstWhere((item) => item.id == id, orElse: () => catalog.first);

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
      folgaHero: p.id == 'folego'
          ? const Color(0xFFC6F135)
          : const Color(0xFFBAF095),
      apertadoHero: const Color(0xFFFFD18C),
      estouradoHero: const Color(0xFFFFB6B0),
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
      fromId('folego', Theme.of(context).brightness);

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
