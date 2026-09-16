import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/statement_import.dart';
import 'folego_repository.dart';

extension FolegoRepositoryStatementImport on FolegoRepository {
  Future<String> stageStatementImport({
    required String spaceId,
    required String filename,
    required StatementImportFileType fileType,
    required StatementImportSourceKind sourceKind,
    String? sourceAccountId,
    String? sourceCardId,
    String? sourceInstitution,
    required String fileFingerprint,
    required Map<String, dynamic> configuration,
    required List<StatementImportCandidate> candidates,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'stage_transaction_import',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_filename': filename,
        'p_file_type': fileType.dbKey,
        'p_source_kind': sourceKind.dbKey,
        'p_source_account_id': sourceAccountId,
        'p_source_card_id': sourceCardId,
        'p_source_institution': _nullable(sourceInstitution),
        'p_file_fingerprint': fileFingerprint,
        'p_configuration': configuration,
        'p_parser_version': '1.0',
        'p_rows': candidates.map((item) => item.toStageJson()).toList(growable: false),
      },
    );
    return data as String;
  }

  Future<StatementImportBatch> getStatementImportBatch({
    required String spaceId,
    required String batchId,
  }) async {
    final data = await Supabase.instance.client
        .from('import_batches')
        .select('''
          id,space_id,filename,file_type,source_kind,source_account_id,source_card_id,
          source_institution,status,total_rows,imported_rows,ignored_rows,duplicate_rows,error_rows
        ''')
        .eq('space_id', spaceId)
        .eq('id', batchId)
        .single();
    return StatementImportBatch.fromJson(data);
  }

  Future<List<StatementImportRow>> listStatementImportRows({
    required String spaceId,
    required String batchId,
  }) async {
    final data = await Supabase.instance.client
        .from('import_rows')
        .select('''
          id,batch_id,row_number,occurred_at,description,merchant,amount,direction,external_id,
          candidate_type,final_type,category_id,counterpart_account_id,invoice_id,duplicate_state,
          user_decision,status,reason,error_text,imported_event_id
        ''')
        .eq('space_id', spaceId)
        .eq('batch_id', batchId)
        .order('row_number');
    return List<Map<String, dynamic>>.from(data)
        .map(StatementImportRow.fromJson)
        .toList(growable: false);
  }

  Future<void> updateStatementImportRows({
    required String spaceId,
    required String batchId,
    required List<StatementImportRow> rows,
  }) async {
    if (rows.isEmpty) return;
    await Supabase.instance.client.rpc(
      'update_import_rows_review',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
        'p_updates': rows.map((row) => row.toReviewPatch()).toList(growable: false),
      },
    );
  }

  Future<StatementImportResult> confirmStatementImport({
    required String spaceId,
    required String batchId,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'confirm_transaction_import',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
      },
    );
    return StatementImportResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> cancelStatementImport({
    required String spaceId,
    required String batchId,
  }) async {
    await Supabase.instance.client.rpc(
      'cancel_transaction_import',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
      },
    );
  }

  Future<List<StatementImportInvoiceOption>> listStatementImportInvoices(
    String spaceId, {
    String? cardId,
  }) async {
    var query = Supabase.instance.client
        .from('card_invoices')
        .select('id,card_id,due_date,status,card:credit_cards!inner(name,active)')
        .eq('space_id', spaceId)
        .eq('card.active', true)
        .neq('status', 'paid')
        .neq('status', 'cancelled');
    if (cardId != null) {
      query = query.eq('card_id', cardId);
    }
    final data = await query.order('due_date');
    return List<Map<String, dynamic>>.from(data)
        .map(StatementImportInvoiceOption.fromJson)
        .toList(growable: false);
  }
}

String? _nullable(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
