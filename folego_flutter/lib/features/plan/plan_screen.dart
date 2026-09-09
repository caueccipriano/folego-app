import 'package:flutter/material.dart';

import '../../shared/widgets/page_placeholder.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PagePlaceholder(
      title: 'Planejamento',
      description: 'Orçamentos, recorrências, projeções e o simulador “Posso comprar?” serão reunidos aqui.',
      icon: Icons.event_available_rounded,
    );
  }
}
