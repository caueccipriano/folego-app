# FÔLEGO — confirmação pós-gravação por lançamento, fase ACK v1

## Estado desta fase
- **GitHub:** novos componentes isolados (migration, Edge `sheet-row-ack`, complemento Apps Script e cliente de consulta). Sem troca da Edge `sheet-sync` v18.
- **Ativação:** aplicar migração aditiva e implantar Edge nova apenas após testes; a rotina real do Apps Script **não está acessível pelo conector** e não será trocada sem acesso e revisão. Enquanto não houver ACK real, a UI permanece corretamente em **sem confirmação**.
- **Retorno às condições antigas:** sem o complemento, a sincronização existente funciona como antes; recibos não geram qualquer lançamento.

## Protocolo
Após o Apps Script escrever a linha do `pull`, `SpreadsheetApp.flush()` e **reler** a linha (incluindo ID), pode enviar:
```json
{"action":"pull_ack","rows":[
  {"id":"event:<uuid>","updated_at":"2026-10-14T03:00:00.000Z","sha256":"<sha256-dos-valores-realmente-escritos>"}
]}
```
Via POST `/functions/v1/sheet-row-ack` com os mesmos cabeçalhos de integração `x-spreadsheet-id` e `x-folego-sync-token` da função atual. Nunca incluir token no repositório, nos resultados ou em logs.

A Edge verifica credenciais e escopo do espaço, encontra o evento pelo ID do protocolo `pull`, limita lotes a 100 itens e chama RPC restrita a `service_role`. A RPC valida:
1. integração habilitada e espaço correto;
2. evento confirmado, ID de planilha associado ao evento;
3. versão `updated_at` **exatamente igual** ao backend;
4. idempotência única por integração, evento e versão; conteúdo do mesmo recibo imutável.

Respostas por linha:
- `applied`: recibo novo registrado;
- `already_acknowledged`: repetição idêntica aceita sem alteração;
- `stale_version`: não aceita versão antiga;
- `row_identity_conflict`: evento errado para a linha;
- `receipt_conflict`: mesmo evento/versão com outro conteúdo;
- `invalid_request`, `event_not_found` ou erro técnico: **não afirmar sucesso**.

O HTTP 200 da Edge **não implica** sucesso do lote; o script deve interpretar cada resultado. A UI lê apenas recibos associados à versão corrente do evento via RPC com verificação de `auth.uid()` e `space_members`. Recibos antigos são retidos para diagnóstico histórico, mas nunca interpretados como confirmação corrente.

## Escopo de dados
A tabela guarda ID de integração, ID de evento, ID público da linha, versão, hash dos campos reobservados e horário de confirmação. **Não** armazena saldo, descrição, valor, comentário nem token. RLS habilitada, sem SELECT/INSERT/UPDATE direto para `anon`/`authenticated`, acesso via Edge com token e RPCs estritamente limitadas. Não cria triggers em eventos, não altera `financial_events`, `financial_impacts`, faturas, categorias, comentários ou saldos.

## Limites
- **ACK é atestação do Apps Script após escrita**, não prova independente de que todos os cálculos da planilha e do aplicativo coincidem.
- A tela de auditoria mostra amostra; não reflete todo o histórico.
- Antes de instalar o complemento no projeto real, confirmar fluxo de `pull` e local de gravação de cada linha; garantir que o script chame ACK **só para linhas realmente aplicadas**, não `PULLED`, `CATEGORY SYNC` nem conflitos.
- A migração não resolve os 9 avisos de conflitos de categoria já existentes na planilha; preservá-los para revisão.
- Sem acesso ao editor Apps Script, esta fase oferece apenas infraestrutura pronta; **não reportar recibos existentes ou integração completa**.

## Testes/release
- Simulações Node do complemento e estados por linha; testes Dart dos rótulos e privacidade.
- Validação do SQL em ambiente conectado, permissão `authenticated` sem escrita e checagem de resultado para erro/versão.
- CI Flutter, integração e Playwright antes de merge da tela pública.
- Check de 401 sem token na Edge nova, sem gastar credenciais reais em testes.
