import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/shared/widgets/financial_note_editor.dart';

class NoteRepository extends FolegoRepository {
  NoteRepository() : super(SupabaseClient('https://example.supabase.co', 'test',
    authOptions: const AuthClientOptions(autoRefreshToken: false)));
  String? user = 'user-a';
  Map<String, dynamic> note = {'content': 'original', 'revision': 1};
  bool conflict = false;
  String? savedTargetType;
  String? savedTargetId;
  final sessions = StreamController<String?>.broadcast();
  Completer<Map<String, dynamic>?>? pending;
  @override
  String? get commentsUserId => user;
  @override
  Stream<String?> get commentsSessionChanges => sessions.stream;
  @override
  Future<Map<String, dynamic>?> getFinancialNote({required String spaceId,
    required String targetType, required String targetId}) async {
    if (pending != null) return await pending!.future;
    return Map.of(note);
  }
  @override
  Future<Map<String, dynamic>> saveFinancialNote({required String spaceId,
    required String targetType, required String targetId, required String content,
    required int revision, required String userId}) async {
    if (conflict || revision != note['revision']) throw StateError('conflict');
    savedTargetType = targetType;
    savedTargetId = targetId;
    note = {'content': content, 'revision': revision + 1};
    return Map.of(note);
  }
}
Widget screen(NoteRepository repo, {
  String id = 'event-a',
  String type = 'event',
}) => MaterialApp(home: Scaffold(body:
  FinancialNoteEditor(repository: repo, spaceId: 'space-a', targetType: type, targetId: id)));

void main() {
  testWidgets('reads, edits, and saves a versioned note', (tester) async {
    final repo = NoteRepository();
    await tester.pumpWidget(screen(repo)); await tester.pumpAndSettle();
    expect(find.text('original'), findsOneWidget);
    await tester.tap(find.text('editar comentário')); await tester.pump();
    await tester.enterText(find.byType(TextField), 'nova nota');
    await tester.tap(find.text('salvar comentário')); await tester.pumpAndSettle();
    expect(repo.note['revision'], 2); expect(find.text('nova nota'), findsOneWidget);
  });
  testWidgets('comments attach to the purchase ID, not the card or invoice',
      (tester) async {
    final repo = NoteRepository();
    await tester.pumpWidget(screen(repo,
      id: 'purchase-infinitypay-1', type: 'card_purchase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('editar comentário'));
    await tester.pump();
    await tester.enterText(find.byType(TextField),
      'Compra da mãe: novembro em aberto');
    await tester.tap(find.text('salvar comentário'));
    await tester.pumpAndSettle();
    expect(repo.savedTargetType, 'card_purchase');
    expect(repo.savedTargetId, 'purchase-infinitypay-1');
    expect(repo.note['content'], 'Compra da mãe: novembro em aberto');
    expect(repo.note['revision'], 2);
  });

  testWidgets('conflict preserves draft and requires explicit review', (tester) async {
    final repo = NoteRepository();
    await tester.pumpWidget(screen(repo)); await tester.pumpAndSettle();
    await tester.tap(find.text('editar comentário')); await tester.pump();
    await tester.enterText(find.byType(TextField), 'rascunho local');
    repo.note = {'content': 'alterado na planilha', 'revision': 2}; repo.conflict = true;
    await tester.tap(find.text('salvar comentário')); await tester.pumpAndSettle();
    expect(find.text('rascunho local'), findsOneWidget);
    expect(repo.note['content'], 'alterado na planilha');
    await tester.tap(find.text('conferir versão atual')); await tester.pumpAndSettle();
    expect(find.textContaining('alterado na planilha'), findsOneWidget);
    expect(find.text('rascunho local'), findsOneWidget);
    repo.conflict = false;
    await tester.tap(find.text('salvar comentário')); await tester.pumpAndSettle();
    expect(repo.note['revision'], 3);
  });
  testWidgets('late response for another target is ignored', (tester) async {
    final repo = NoteRepository(); final delayed = Completer<Map<String, dynamic>?>();
    repo.pending = delayed;
    await tester.pumpWidget(screen(repo)); await tester.pump();
    repo.pending = null; repo.note = {'content': 'target-b', 'revision': 1};
    await tester.pumpWidget(screen(repo, id: 'event-b')); await tester.pumpAndSettle();
    delayed.complete({'content': 'private target-a', 'revision': 1}); await tester.pumpAndSettle();
    expect(find.text('target-b'), findsOneWidget); expect(find.text('private target-a'), findsNothing);
  });
  testWidgets('logout clears the mounted note immediately', (tester) async {
    final repo = NoteRepository();
    await tester.pumpWidget(screen(repo)); await tester.pumpAndSettle();
    expect(find.text('original'), findsOneWidget);
    repo.user = null; repo.sessions.add(null); await tester.pumpAndSettle();
    expect(find.text('original'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
