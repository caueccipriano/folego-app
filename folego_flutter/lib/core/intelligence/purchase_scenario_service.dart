import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/projection_model.dart';
import '../../data/repositories/folego_repository.dart';

class PurchaseScenario {
  const PurchaseScenario({
    required this.baseline,
    required this.withPurchase,
    required this.monthlyPayment,
    required this.firstNegativeMonth,
  });
  final ProjectionResult baseline;
  final ProjectionResult withPurchase;
  final double monthlyPayment;
  final DateTime? firstNegativeMonth;
}

/// Usa o MESMO motor oficial de projeção do app para os dois cenários.
/// Não grava lançamentos: a compra existe apenas como ajuste de simulação.
class PurchaseScenarioService {
  const PurchaseScenarioService(this.repository);
  final FolegoRepository repository;

  Future<PurchaseScenario> simulate({
    required String spaceId,
    required double purchaseAmount,
    required int installments,
    int horizonMonths = 12,
    DateTime? purchaseDate,
  }) async {
    if (!purchaseAmount.isFinite || purchaseAmount <= 0 ||
        installments < 1 || installments > 48 ||
        horizonMonths < 1 || horizonMonths > 24) {
      throw ArgumentError('Confira o valor, as parcelas e o período.');
    }
    final date = purchaseDate ?? DateTime.now();
    final adjustment = ProjectionAdjustment(
      id: 'purchase-scenario',
      name: 'Compra simulada',
      // Simulação de saída mensal; não presume uma fatura/cartão específico.
      component: 'direct_expense',
      amountDelta: purchaseAmount / installments,
      frequency: 'monthly',
      startsOn: date,
      endsOn: projectionMonthlyEndDate(date, installments),
    );
    final baseline = await repository.getProjection(
      spaceId: spaceId, horizonMonths: horizonMonths);
    final withPurchase = await repository.getProjection(
      spaceId: spaceId, horizonMonths: horizonMonths,
      adjustments: [adjustment]);
    if (!baseline.hasProjectionInputs || !withPurchase.hasProjectionInputs ||
        baseline.months.isEmpty || withPurchase.months.isEmpty) {
      throw StateError('Configure suas projeções antes de simular compras.');
    }
    // Backend is authoritative. Until paid receipts are verified server-side,
    // never bypass the quota based on a client-side premium flag.
    final quota = await Supabase.instance.client.rpc('consume_free_simulation');
    final row = quota is List && quota.isNotEmpty ? quota.first : null;
    if (row is! Map || row['allowed'] != true) {
      throw StateError('Limite mensal de simulações atingido.');
    }
    DateTime? negative;
    for (final month in withPurchase.months) {
      if (month.closingProjected < 0) {
        negative = month.month;
        break;
      }
    }
    return PurchaseScenario(
      baseline: baseline,
      withPurchase: withPurchase,
      monthlyPayment: purchaseAmount / installments,
      firstNegativeMonth: negative,
    );
  }
}
