import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// Container estrutural reutilizável para páginas do Fôlego.
///
/// Centraliza o conteúdo, limita a largura no desktop e aplica padding
/// horizontal adaptativo conforme os breakpoints oficiais. O limite é escolhido
/// por cada tela; não existe um maxWidth global imposto pelo Shell.
class AppContentContainer extends StatelessWidget {
  const AppContentContainer({
    super.key,
    required this.maxWidth,
    required this.child,
    this.verticalPadding = 0,
    this.alignment = Alignment.topCenter,
    this.fillHeight = false,
  });

  const AppContentContainer.auth({
    super.key,
    required this.child,
    this.verticalPadding = 0,
    this.alignment = Alignment.topCenter,
    this.fillHeight = false,
  }) : maxWidth = AppContentWidths.auth;

  const AppContentContainer.form({
    super.key,
    required this.child,
    this.verticalPadding = 0,
    this.alignment = Alignment.topCenter,
    this.fillHeight = false,
  }) : maxWidth = AppContentWidths.form;

  const AppContentContainer.list({
    super.key,
    required this.child,
    this.verticalPadding = 0,
    this.alignment = Alignment.topCenter,
    this.fillHeight = false,
  }) : maxWidth = AppContentWidths.list;

  const AppContentContainer.dashboard({
    super.key,
    required this.child,
    this.verticalPadding = 0,
    this.alignment = Alignment.topCenter,
    this.fillHeight = false,
  }) : maxWidth = AppContentWidths.dashboard;

  final double maxWidth;
  final Widget child;
  final double verticalPadding;
  final AlignmentGeometry alignment;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final horizontalPadding =
            AppResponsiveSpacing.horizontalForWidth(availableWidth);

        final height = fillHeight && constraints.hasBoundedHeight
            ? constraints.maxHeight
            : null;

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
