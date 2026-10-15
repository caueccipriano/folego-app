import 'package:flutter/material.dart';

import '../../data/repositories/folego_repository.dart';
import '../transactions/statement_import_screen.dart';
import '../wallet/wallet_instrument_management.dart';
import '../profile/sheet_sync_status_card.dart';

/// All routes are optional and use the existing reviewed registration/import
/// flows. Selecting a route never creates financial records by itself.
class GettingStartedScreen extends StatelessWidget {
  const GettingStartedScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });
  final FolegoRepository repository;
  final String spaceId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('comece do seu jeito')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'como você quer organizar suas finanças?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha o caminho mais conveniente. Você pode combinar os três depois.',
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.edit_outlined),
                title: const Text('começar manualmente'),
                subtitle: const Text(
                  'Cadastre uma conta com o saldo atual. Depois, adicione sua próxima entrada e compromissos.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showWalletAccountEditor(
                  context: context,
                  repository: repository,
                  spaceId: spaceId,
                ),
              ),
            ),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('importar um extrato'),
                subtitle: const Text(
                  'Escolha o arquivo, confira conta, categorias e possíveis duplicatas antes de confirmar.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StatementImportScreen(
                      repository: repository,
                      spaceId: spaceId,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('usar uma planilha'),
                subtitle: const Text(
                  'Integração opcional; confira a conexão antes de importar os mesmos dados.',
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Se você já usa uma planilha integrada, confira abaixo a comunicação com este espaço. Uma integração não conectada precisa ser configurada antes da sincronização. Evite importar o mesmo período também pelo extrato sem revisar as duplicatas.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SheetSyncStatusCard(
                      spaceId: spaceId,
                      loadStatus: repository.getSheetSyncStatus,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Para um Fôlego útil: saldo atual → próxima entrada → compromissos → limites de gastos. Limite do cartão e benefícios ficam separados do dinheiro livre.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('continuar no app'),
            ),
          ],
        ),
      ),
    ),
  );
}
