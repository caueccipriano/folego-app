import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_import.dart';
import 'folego_repository.dart';

extension FolegoRepositoryTransactionImport on FolegoRepository {
  SupabaseClient get _importClient => Supabase.instance.client;

  Future<List<ImportSourceOption>> listImportSources(String spaceId) async {
    final accountsResponse = await _importClient
        .from('accounts')
        .select('id,name,type,institution')
        .eq('space_id', spaceId)
        .eq('active', true)
        .order('name');
    final cardsResponse = await _importClient
        .from('credit_cards')
        .select('id,name,issuer')
        .eq('space_id', spaceId)
        .eq('active', true)
        .order('name');
    final values = <ImportSourceOption>[
      for (final row in List<Map<String, dynamic>>.from(accountsResponse))
        ImportSourceOption(
          id: row['id'] as String,
          name: row['name'] as String,
          kind: row['type'] == 'benefit' ? 'benefit' : 'account',
          institution: row['institution'] as String?,
        ),
      for (final row in List<Map<String, dynamic>>.from(cardsResponse))
        ImportSourceOption(
          id: row['id'] as String,
          name: row['name'] as String,
          kind: 'card',
          institution: row['issuer'] as String?,
        ),
    ];
    return values;
  }

  Future<String> stageTransactionImport({
    required String spaceId,
    required String filename,
    required String fileType,
    required String sourceKind,
    required List<ImportCandidate> candidates,
    String? sourceAccountId,
    String? sourceCardId,
    String? sourceInstitution,
    String? fileFingerprint,
    Map<String, dynamic> configuration = const <String, dynamic>{},
    String parserVersion = '1.0',
  }) async {
    final data = await _importClient.rpc(
      'stage_transaction_import',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_filename': filename,
        'p_file_type': fileType,
        'p_source_kind': sourceKind,
        'p_source_account_id': sourceAccountId,
        'p_source_card_id': sourceCardId,
        'p_source_institution': sourceInstitution,
        'p_file_fingerprint': fileFingerprint,
        'p_configuration': configuration,
        'p_parser_version': parserVersion,
        'p_rows': candidates.map((row) => row.toStagingJson()).toList(growable: false),
      },
    );
    return data as String;
  }

  Future<ImportBatch> getImportBatch({
    required String spaceId,
    required String batchId,
  }) async {
    final response = await _importClient
        .from('import_batches')
        .select('''
          id,space_id,filename,file_type,source_kind,source_account_id,source_card_id,status,
          total_rows,selected_rows,imported_rows,ignored_rows,duplicate_rows,error_rows
        ''')
        .eq('space_id', spaceId)
        .eq('id', batchId)
        .single();
    return ImportBatch.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<ImportRow>> listImportRows({
    required String spaceId,
    required String batchId,
  }) async {
    final response = await _importClient
        .from('import_rows')
        .select('''
          id,row_number,occurred_at,description,merchant,amount,direction,candidate_type,final_type,
          external_id,category_id,counterpart_account_id,invoice_id,duplicate_state,user_decision,status,
          reason,error_text,imported_event_id
        ''')
        .eq('space_id', spaceId)
        .eq('batch_id', batchId)
        .order('row_number');
    return List<Map<String, dynamic>>.from(response)
        .map(ImportRow.fromJson)
        .toList(growable: false);
  }

  Future<void> updateImportRowsReview({
    required String spaceId,
    required String batchId,
    required List<ImportRow> rows,
  }) async {
    if (rows.isEmpty) return;
    await _importClient.rpc(
      'update_import_rows_review',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
        'p_updates': rows.map((row) => row.toReviewJson()).toList(growable: false),
      },
    );
  }

  Future<ImportConfirmationResult> confirmTransactionImport({
    required String spaceId,
    required String batchId,
  }) async {
    final data = await _importClient.rpc(
      'confirm_transaction_import',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
      },
    );
    return ImportConfirmationResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> cancelTransactionImport({
    required String spaceId,
    required String batchId,
  }) async {
    await _importClient.rpc(
      'cancel_transaction_import',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_batch_id': batchId,
      },
    );
  }

  Future<List<ImportInvoiceOption>> listImportInvoiceOptions(String spaceId) async {
    final response = await _importClient
        .from('card_invoices')
        .select('id,card_id,due_date,status')
        .eq('space_id', spaceId)
        .neq('status', 'paid')
        .neq('status', 'cancelled')
        .order('due_date', ascending: false)
        .limit(120);
    return List<Map<String, dynamic>>.from(response)
        .map(ImportInvoiceOption.fromJson)
        .toList(growable: false);
  }
}
