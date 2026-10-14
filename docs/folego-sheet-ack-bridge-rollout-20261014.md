# FÔLEGO Sync 2.0 — Bridge ACK readback (fase controlada)

## Diagnóstico confirmado — 14/10/2026
- A versão pública do FÔLEGO já possui auditoria por lançamento.
- No backend conectado, a tabela `sheet_sync_delivery_receipts`, as duas RPCs e a Edge Function `sheet-row-ack` estão instaladas; **nenhum recibo estava registrado** na consulta de diagnóstico.
- O servidor `sheet-sync` v18 envia `id` e `updated_at` por linha em `pull`.
- O Apps Script de categorias/SYNC (PR #100) permanece em **draft**. O acesso ao editor online nesta sessão não foi obtido. Esta entrega NÃO altera aquele editor nem ativa o ACK real.

## Mudanças propostas, ainda desativadas
- `FolegoSync.gs` recebe uma ponte que verifica `FOLEGO_SHEET_ACK_ENABLED === 'true'`; ausente ou `false` significa comportamento histórico **inalterado**.
- Após gravar ou conferir a linha em `Lancamentos`, relê `B:U` após `SpreadsheetApp.flush()`, verifica ID exato, descrição, valor, tipo, categoria legada, conta/cartão, origem `Fôlego App`, status `Confirmado` e estado `PULLED`. A verificação falha se algo divergir.
- Somente linhas observadas com segurança seguem para `folegoEnviarAckAposGravacao_`, usando o endpoint independente `sheet-row-ack` e o token já guardado nas Script Properties.
- Cada resposta é classificada pelo status da linha: `applied` e `already_acknowledged` são aceitos, `stale_version`, `receipt_conflict`, `server_error` e outros não representam sucesso. Logs expõem apenas **contagens**, jamais identificadores ou tokens.
- Se o complemento ainda não existir, não envia ACK. Falhas de rede não afetam o fluxo contábil antigo nem criam lançamentos, categorias ou saldos.

## Limites honestos deste piloto
- Não reconcilia **todos** os 250 eventos históricos retroativamente; apenas entradas obtidas em futuras consultas de `pull` e cujo estado observado coincida com o evento retornado pelo backend.
- Atualmente não há fila persistente de retry de ACK. Uma falha transitória após avanço do cursor deixa o registro **sem confirmação**, e isso deve continuar visível no app; não marcar artificialmente como sucesso.
- A verificação é um recibo de gravação e reobservação, **não validação financeira de igualdade integral** entre os dois livros contábeis.
- Categoria editada localmente, conflitos do PR #100, transferências divergentes e eventos protegidos não podem ser marcados como conciliados à força.

## Aceite antes de habilitar a propriedade
1. Merge/review do PR #100, autenticidade e versão do código no editor real.
2. Rodar os testes sintéticos Node e revisão da CI; verificar que não houve alterações no banco e planilha.
3. Fazer instalação do addon `folego-row-ack-addon.gs` e deste bridge no Apps Script somente após backup da fonte existente.
4. Habilitar a flag num **ambiente isolado com 2 contas e 2 linhas sintéticas**; simular repetição idempotente, versão antiga, local editado, indisponibilidade do endpoint.
5. Obter confirmação de que o backend tem recibos de versão corrente, sem nenhum número financeiro alterar.
6. Só então considerar `FOLEGO_SHEET_ACK_ENABLED=true` na instância real, com rollback por flag e observação do ciclo.

## Rollback e segurança
- Desabilitar a flag mantém o ciclo original; o complemento não escreve em finanças.
- A migração e a Edge existente permanecem inalteradas.
- Nenhum comentário, fórmula, validação, trigger ou histórico foi modificado nesta etapa.
