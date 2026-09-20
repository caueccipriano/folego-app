import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/debt_detail.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_debts.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';
import 'debt_form_sheet.dart';
import 'debt_payment_sheet.dart';

class WalletDebtDetailScreen extends StatefulWidget {
  const WalletDebtDetailScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.debt,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletDebt debt;

  @override
  State<WalletDebtDetailScreen> createState() => _WalletDebtDetailScreenState();
}

class _WalletDebtDetailScreenState extends State<WalletDebtDetailScreen> {
  bool _loading = true;
  String? _error;
  DebtDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await widget.repository.getDebtDetail(
        spaceId: widget.spaceId,
        debtId: widget.debt.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _edit() async {
    final detail = _detail;
    if (detail == null) return;
    final changed = await showDebtFormSheet(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      existing: detail,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _archive() async {
    final detail = _detail;
    if (detail == null || !detail.debt.isActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('arquivar esta dívida?'),
        content: const Text(
          'Ela sai das obrigações ativas e da agenda. Pagamentos e histórico financeiro continuam preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('arquivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.archiveDebt(
      spaceId: widget.spaceId,
      debtId: detail.debt.id,
    );
    AppRealtimeRegistry.coordinator?.invalidateDomains({
      AppRealtimeDomain.home,
      AppRealtimeDomain.wallet,
    });
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _close() async {
    final detail = _detail;
    if (detail == null || detail.debt.remainingBalance > .001) return;
    await widget.repository.closeDebt(
      spaceId: widget.spaceId,
      debtId: detail.debt.id,
    );
    AppRealtimeRegistry.coordinator?.invalidateDomains({
      AppRealtimeDomain.home,
      AppRealtimeDomain.wallet,
    });
    if (mounted) await _load();
  }

  Future<void> _pay(DebtInstallmentRecord installment) async {
    final detail = _detail;
    if (detail == null || !detail.debt.isActive || !installment.canPay) return;
    final paid = await showDebtPaymentSheet(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      debt: detail.debt,
      installment: installment,
    );
    if (paid == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final debt = _detail?.debt ?? widget.debt;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: AppContentContainer.list(
          fillHeight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: AppPageHeader(
                  title: debt.name,
                  subtitle: _detail == null
                      ? 'detalhes da dívida'
                      : '${debt.creditor} · ${debtTypeLabel(debt.debtType)}',
                  leading: IconButton(
                    tooltip: 'voltar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(AppIcons.back),
                  ),
                  trailing: _detail?.debt.isActive == true
                      ? IconButton(
                          tooltip: 'editar',
                          onPressed: _edit,
                          icon: const Icon(AppIcons.edit),
                        )
                      : null,
                ),
              ),
              Expanded(child: _buildBody(brightness)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Brightness brightness) {
    if (_loading && _detail == null) {
      return const AppLoadingState(label: 'organizando os detalhes da dívida');
    }
    if (_error != null && _detail == null) {
      return AppErrorState(
        title: 'não consegui carregar esta dívida',
        description: _error,
        onRetry: _load,
      );
    }

    final detail = _detail!;
    final debt = detail.debt;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final openInstallments = detail.installments.where((item) => !item.isPaid).toList();
    final paidInstallments = detail.installments.where((item) => item.isPaid).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 44),
        children: [
          const SizedBox(height: 4),
          _DebtAmountCard(detail: detail),
          const SizedBox(height: 14),
          _DebtProgressCard(detail: detail),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: AppIcons.calendar,
                text: '${debt.totalInstallments} parcelas',
              ),
              if (debt.interestRateMonthly != null)
                _MetaChip(
                  icon: AppIcons.financeInterest,
                  text: '${debt.interestRateMonthly!.toStringAsFixed(2)}% a.m.',
                ),
              _MetaChip(
                icon: debt.isPaid ? AppIcons.check : AppIcons.debt,
                text: debt.isArchived
                    ? 'arquivada'
                    : debt.isPaid
                    ? 'quitada'
                    : 'ativa',
              ),
            ],
          ),
          if (debt.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _InfoBox(text: debt.notes!.trim()),
          ],
          const SizedBox(height: 28),
          _SectionTitle(
            title: 'próximas parcelas',
            subtitle: 'o que ainda falta liquidar',
          ),
          const SizedBox(height: 10),
          if (openInstallments.isEmpty)
            _EmptyLine(text: 'nenhuma parcela em aberto')
          else
            ...openInstallments.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InstallmentCard(
                  item: item,
                  enabled: debt.isActive,
                  onPay: () => _pay(item),
                ),
              ),
            ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'pagamentos',
            subtitle: 'histórico ligado aos lançamentos de cash',
          ),
          const SizedBox(height: 10),
          if (detail.payments.isEmpty)
            _EmptyLine(text: 'nenhum pagamento registrado')
          else
            ...detail.payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PaymentCard(payment: payment),
              ),
            ),
          if (paidInstallments.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'parcelas concluídas',
              subtitle: '${paidInstallments.length} liquidadas',
            ),
            const SizedBox(height: 10),
            ...paidInstallments.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InstallmentCard(
                  item: item,
                  enabled: false,
                  onPay: null,
                ),
              ),
            ),
          ],
          if (debt.isActive) ...[
            const SizedBox(height: 28),
            if (debt.remainingBalance <= .001)
              OutlinedButton.icon(
                onPressed: _close,
                icon: const Icon(AppIcons.check, size: 18),
                label: const Text('encerrar como quitada'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _archive,
              icon: const Icon(AppIcons.close, size: 18),
              label: const Text('arquivar dívida'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DebtAmountCard extends StatelessWidget {
  const _DebtAmountCard({required this.detail});
  final DebtDetail detail;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple(brightness),
        borderRadius: BorderRadius.circular(AppRadii.feature),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('saldo restante', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            Formatters.money(detail.debt.remainingBalance),
            style: AppTypography.money(context, fontSize: 34, color: AppColors.lime),
          ),
          const SizedBox(height: 7),
          Text(
            'de ${Formatters.money(detail.debt.originalAmount)} originalmente',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DebtProgressCard extends StatelessWidget {
  const _DebtProgressCard({required this.detail});
  final DebtDetail detail;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Formatters.money(detail.paidAmount)} pagos',
                  style: AppTypography.label(context, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${(detail.progress * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: detail.progress),
        ],
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({
    required this.item,
    required this.enabled,
    required this.onPay,
  });
  final DebtInstallmentRecord item;
  final bool enabled;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        children: [
          Icon(
            item.isOverdue ? AppIcons.warning : item.isPaid ? AppIcons.check : AppIcons.calendar,
            size: 19,
            color: item.isOverdue ? AppColors.expenseText(brightness) : secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'parcela ${item.installmentNumber} · ${Formatters.money(item.remainingAmount)}',
                  style: AppTypography.label(context, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.isOverdue ? 'atrasada · ' : ''}${Formatters.shortDate.format(item.dueDate)}'
                  '${item.paidAmount > 0 && !item.isPaid ? ' · ${Formatters.money(item.paidAmount)} já pagos' : ''}',
                  style: AppTypography.body(context, fontSize: 10, color: secondary),
                ),
              ],
            ),
          ),
          if (enabled && onPay != null)
            TextButton(onPressed: onPay, child: const Text('pagar')),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final DebtPaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.check, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'parcela ${payment.installmentNumber} · ${payment.accountName}\n${Formatters.shortDate.format(payment.paidAt)}',
              style: AppTypography.body(context, fontSize: 11),
            ),
          ),
          Text(
            Formatters.money(payment.amount),
            style: AppTypography.label(context, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: title, subtitle: subtitle);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: AppTypography.label(context, fontSize: 10)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(text, style: AppTypography.body(context, fontSize: 11)),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: AppTypography.body(
          context,
          fontSize: 11,
          color: AppColors.secondaryText(Theme.of(context).brightness),
        ),
      ),
    );
  }
}
