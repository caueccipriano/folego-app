import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
    required this.onSignOut,
  });

  final Future<void> Function() onCompleted;
  final Future<void> Function() onSignOut;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = <_IntroStep>[
    _IntroStep(
      icon: AppIcons.wallet,
      title: 'seu saldo não é o que você pode gastar',
      body:
          'o Fôlego cruza o que você tem com compromissos, orçamento e a próxima entrada antes de mostrar quanto está realmente livre.',
    ),
    _IntroStep(
      icon: AppIcons.account,
      title: 'organize onde seu dinheiro está',
      body:
          'contas, cartões, benefícios e dívidas ficam no mesmo lugar — sem misturar saldo bancário com limite de crédito.',
    ),
    _IntroStep(
      icon: AppIcons.transactions,
      title: 'anote sem virar planilha',
      body:
          'registre gastos, receitas e recorrências de um jeito rápido. o app organiza a rotina sem transformar tudo em burocracia.',
    ),
    _IntroStep(
      icon: AppIcons.flame,
      title: 'quanto dá pra gastar hoje?',
      body:
          'essa é a pergunta que guia o Fôlego. você pode entrar agora e configurar suas finanças no seu ritmo.',
    ),
  ];

  int _step = 0;
  bool _finishing = false;
  bool _signingOut = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onCompleted();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final current = _steps[_step];
    final last = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: AppContentContainer.form(
          fillHeight: true,
          verticalPadding: 18,
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Fôlego',
                    style: AppTypography.section(context, fontSize: 20),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('onboarding-skip'),
                    onPressed: _finishing ? null : _finish,
                    child: const Text('pular'),
                  ),
                  IconButton(
                    tooltip: 'sair da conta',
                    onPressed: _signingOut ? null : _signOut,
                    icon: _signingOut
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.logout),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(_steps.length, (index) {
                  final active = index <= _step;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == _steps.length - 1 ? 0 : 6,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryPurple(brightness)
                              : AppColors.border(brightness),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _IntroCard(
                    key: ValueKey(_step),
                    step: current,
                    position: _step + 1,
                    total: _steps.length,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _finishing
                            ? null
                            : () => setState(() => _step -= 1),
                        icon: const Icon(AppIcons.back),
                        label: const Text('voltar'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: _step > 0 ? 1 : 2,
                    child: FilledButton.icon(
                      key: ValueKey(last ? 'onboarding-finish' : 'onboarding-next'),
                      onPressed: _finishing
                          ? null
                          : last
                          ? _finish
                          : () => setState(() => _step += 1),
                      icon: _finishing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(last ? AppIcons.check : AppIcons.forward),
                      label: Text(last ? 'entrar no Fôlego' : 'continuar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'você não precisa configurar tudo agora',
                textAlign: TextAlign.center,
                style: AppTypography.label(
                  context,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    super.key,
    required this.step,
    required this.position,
    required this.total,
  });

  final _IntroStep step;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Semantics(
      label: 'passo $position de $total: ${step.title}',
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(step.icon, color: purple, size: 27),
              ),
              const SizedBox(height: 24),
              Text(
                step.title,
                style: AppTypography.section(context, fontSize: 24),
              ),
              const SizedBox(height: 12),
              Text(
                step.body,
                style: AppTypography.body(
                  context,
                  fontSize: 14,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroStep {
  const _IntroStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
