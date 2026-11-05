import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';

/// The Fôlego editorial backdrop: quiet, palette-aware ambient light.
/// This draws only inexpensive gradients behind its child. It never adds a
/// compositor blur or intercepts touches in the iPhone PWA.
class FolegoAmbientBackdrop extends StatelessWidget {
  const FolegoAmbientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    if (MediaQuery.highContrastOf(context)) {
      return ColoredBox(color: tokens.fundo, child: child);
    }

    // O estilo Fluxo evita brilhos decorativos: os dados são o destaque.
    // Mantém a mesma key para contratos e testes de navegação.
    if (AppColorSelection.selected.value == 'fluxo') {
      return DecoratedBox(
        key: const ValueKey('folego-ambient-backdrop'),
        decoration: BoxDecoration(color: tokens.fundo),
        child: child,
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final brandGlow = Color.alphaBlend(
      tokens.marca.withValues(alpha: dark ? .19 : .10),
      tokens.fundo,
    );
    final accentGlow = Color.alphaBlend(
      tokens.acao.withValues(alpha: dark ? .095 : .075),
      tokens.fundo,
    );

    return DecoratedBox(
      key: const ValueKey('folego-ambient-backdrop'),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.93, -.94),
          radius: 1.36,
          colors: [brandGlow, tokens.fundo],
          stops: const [0, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.99, .88),
            radius: 1.44,
            colors: [accentGlow.withValues(alpha: .52),
                     accentGlow.withValues(alpha: .0)],
            stops: const [0, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}
