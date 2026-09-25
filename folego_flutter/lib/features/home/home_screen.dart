import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/home_expense_summary.dart';
import '../../data/models/onboarding_state.dart';
import '../../data/models/transaction_filters.dart';
import '../../data/repositories/folego_repository.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/recurring_form_sheet.dart';
import 'quick_register_sheet.dart';
import '../wallet/wallet_instrument_management.dart';
import 'home_expense_navigation_scope.dart';
import 'home_screen_base.dart' as base;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.space,
    required this.repository,
  });

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.home,
      identity: space.id,
      builder: (key) => _HomeContent(
        key: key,
        space: space,
        repository: repository,
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({
    super.key,
    required this.space,
    required this.repository,
  });

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  OnboardingState? _setup;
  bool _loadingSetup = true;
  bool _creatingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  Future<void> _loadSetup() async {
    try {
      final setup = await widget.repository.getOnboardingState(widget.space.id);
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _loadingSetup = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSetup = false);
    }
  }

  Future<void> _addAccount() async {
    if (_creatingAccount) return;
    setState(() => _creatingAccount = true);
    try {
      final saved = await showWalletAccountEditor(
        context: context,
        repository: widget.repository,
        spaceId: widget.space.id,
      );
      if (saved == true && mounted) await _loadSetup();
    } finally {
      if (mounted) setState(() => _creatingAccount = false);
    }
  }


  Future<void> _addRecurringIncome() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => RecurringFormSheet(
        space: widget.space,
        repository: widget.repository,
        initialType: 'income',
      ),
    );
    if (saved == true && mounted) {
      await _loadSetup();
    }
  }

  Future<void> _openQuickRegister(String type) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => QuickRegisterSheet(
        space: widget.space,
        repository: widget.repository,
        initialType: type,
      ),
    );
    if (saved == true && mounted) {
      await _loadSetup();
    }
  }

  void _openExpenseTransactions(String? categoryId) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(
          repository: widget.repository,
          space: widget.space,
          initialFilters: TransactionFilters(
            startDate: monthStart,
            endDate: monthEnd,
            eventTypes: homeExpenseEventTypes,
            categoryId: categoryId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;

    if (!_loadingSetup && setup != null && !setup.folegoReady) {
      return _FirstUseHome(
        setup: setup,
        creatingAccount: _creatingAccount,
        onAddAccount: _addAccount,
        onAddRecurringIncome: _addRecurringIncome,
        onRegisterIncome: () => _openQuickRegister('income'),
        onRegisterExpense: () => _openQuickRegister('expense'),
      );
    }

    // Do not block the whole Home while onboarding state is being checked.
    // Returning a full-screen loading state here makes IndexedStack tabs look
    // blank on iOS/PWA when their async setup is still pending.
    if (_loadingSetup) {
      return HomeExpenseNavigationScope(
        onOpenExpenses: _openExpenseTransactions,
        child: base.HomeScreen(
          space: widget.space,
          repository: widget.repository,
        ),
      );
    }

    return HomeExpenseNavigationScope(
      onOpenExpenses: _openExpenseTransactions,
      child: base.HomeScreen(
        space: widget.space,
        repository: widget.repository,
      ),
    );
  }
}

class _FirstUseHome extends StatelessWidget {
  const _FirstUseHome({
    required this.setup,
    required this.creatingAccount,
    required this.onAddAccount,
    required this.onAddRecurringIncome,
    required this.onRegisterIncome,
    required this.onRegisterExpense,
  });

  final OnboardingState setup;
  final bool creatingAccount;
  final VoidCallback onAddAccount;
  final VoidCallback onAddRecurringIncome;
  final VoidCallback onRegisterIncome;
  final VoidCallback onRegisterExpense;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context)!;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final needsAccount = !setup.hasAccount;

    final title = needsAccount
        ? l10n.firstUseAccountTitle
        : l10n.firstUseIncomeTitle;
    final text = needsAccount
        ? l10n.firstUseAccountBody
        : l10n.firstUseIncomeBody;

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(title: Text(l10n.home.toLowerCase())),
      body: AppContentContainer.dashboard(
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(brightness)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey(
                        needsAccount
                            ? 'first-use-account-icon'
                            : 'first-use-income-icon',
                      ),
                      onTap: needsAccount ? onAddAccount : onAddRecurringIncome,
                      borderRadius: BorderRadius.circular(15),
                      child: Ink(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          needsAccount ? AppIcons.wallet : AppIcons.add,
                          color: purple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: AppTypography.section(context, fontSize: 22),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    text,
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (needsAccount)
                    Semantics(
                      button: true,
                      label: l10n.firstUseAddAccount,
                      child: FilledButton.icon(
                        key: const ValueKey('first-use-add-account'),
                        onPressed: creatingAccount ? null : onAddAccount,
                        icon: creatingAccount
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(AppIcons.add),
                        label: Text(l10n.firstUseAddAccount),
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      key: const ValueKey('first-use-add-recurring-income'),
                      onPressed: onAddRecurringIncome,
                      icon: const Icon(AppIcons.income),
                      label: Text(l10n.firstUseAddRecurringIncome),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('first-use-register-income'),
                            onPressed: onRegisterIncome,
                            icon: const Icon(AppIcons.income, size: 18),
                            label: Text(l10n.firstUseOneOffIncome),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('first-use-register-expense'),
                            onPressed: onRegisterExpense,
                            icon: const Icon(AppIcons.expense, size: 18),
                            label: Text(l10n.firstUseOneOffExpense),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.firstUseAfterTitle,
              style: AppTypography.section(context, fontSize: 17),
            ),
            const SizedBox(height: 12),
            _FirstUseTip(
              icon: AppIcons.transactions,
              title: l10n.firstUseTipTrackTitle,
              text: l10n.firstUseTipTrackBody,
            ),
            const SizedBox(height: 10),
            _FirstUseTip(
              icon: AppIcons.plan,
              title: l10n.firstUseTipPlanTitle,
              text: l10n.firstUseTipPlanBody,
            ),
            const SizedBox(height: 10),
            _FirstUseTip(
              icon: AppIcons.wallet,
              title: l10n.firstUseTipExploreTitle,
              text: l10n.firstUseTipExploreBody,
            ),
            const SizedBox(height: 18),
            Text(
              l10n.firstUseCalculationPending,
              style: AppTypography.label(context, color: secondary),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(child: Divider(color: primary.withValues(alpha: .08))),
          ],
        ),
      ),
    );
  }
}

class _FirstUseTip extends StatelessWidget {
  const _FirstUseTip({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: AppColors.primaryPurple(brightness)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    context,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: AppColors.secondaryText(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
