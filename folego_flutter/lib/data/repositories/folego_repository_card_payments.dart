import 'package:supabase_flutter/supabase_flutter.dart';

import 'folego_repository.dart';

const Set<String> cardInvoicePaymentTypes = {'payment', 'advance'};

extension FolegoRepositoryCardPayments on FolegoRepository {
  Future<String> payCardInvoice({
    required String spaceId,
    required String invoiceId,
    required String accountId,
    required num amount,
    String paymentType = 'payment',
    DateTime? paidAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Deve ser maior que zero.');
    }

    if (!cardInvoicePaymentTypes.contains(paymentType)) {
      throw ArgumentError.value(
        paymentType,
        'paymentType',
        'Tipo de pagamento inválido.',
      );
    }

    final data = await Supabase.instance.client.rpc(
      'pay_card_invoice',
      params: {
        'p_space_id': spaceId,
        'p_invoice_id': invoiceId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_payment_type': paymentType,
        'p_paid_at': (paidAt ?? DateTime.now()).toIso8601String(),
        'p_source': 'app',
        'p_external_id': null,
      },
    );

    return data as String;
  }
}
