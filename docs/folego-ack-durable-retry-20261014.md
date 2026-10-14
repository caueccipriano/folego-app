# FÔLEGO Sync 2.0 — ACK Outbox com recuperação persistente (14/10/2026)

## Motivo da correção
O bridge instalado no Apps Script pode enviar uma confirmação após aplicar uma linha, mas o cursor de `pull` avança mesmo que a resposta do endpoint ACK falhe. Sem persistir a tentativa, a linha pode não voltar na próxima leitura. Esta fase introduz **fila persistente**; não ativa ACK na instância real.

## Mudanças
- `FolegoAckRetry.gs` é novo complemento separado e inerte com `FOLEGO_SHEET_ACK_ENABLED` ausente/`false`.
- `FolegoSync.gs` chama o outbox apenas quando **ACK e proteção de categorias estão habilitados**; se o complemento ou o emissor de ACK faltar, bloqueia o `pull` antes de alterar linhas.
- Um candidato só entra na fila após `SpreadsheetApp.flush()`, leitura de volta e todas as verificações originais de ID, data, forma, descrição, valor, tipo, categoria, origem e estado da linha.
- **Persistir a intenção verificada antes de avançar o cursor** é obrigatório. Se a cota ou gravação de propriedades falhar, a rotina falha sem avançar o cursor.
- O script grava, nas Script Properties, apenas identificador de evento, versão, linha, fingerprint SHA256 de `B:U`, tentativa, backoff e estado. Nunca grava token, descrição, valor, categoria nominal, observação ou conteúdo de comentários na fila.
- Todo novo ciclo percorre a fila **mesmo sem novas linhas**: relê `B:U`, confirma que o hash permanece igual, verifica unicidade do ID na aba e chama o endpoint ACK; idempotência é checada de novo pela função do Supabase.
- Recibo idêntico `applied`/`already_acknowledged` com **mesmo ID retornado** é a única condição que remove a entrada da fila.
- Falhas de transporte mantêm registro com backoff exponencial (5 minutos a 6 horas). Estados `stale_version`, `receipt_conflict`, `row_identity_conflict`, `event_not_found`, `invalid_request`, `integration_disabled`, duplicidade, linha ausente ou alteração local ficam como **revisão**, sem tentativas automáticas perigosas.
- Cota de até **440 registros** no outbox e limite preventivo de **240** antes de novos pulls (máximo 200 linhas no pull): a fila cheia **interrompe avanço de cursor**. Nenhum evento é eliminado silenciosamente.
- Os estados da fila só são apresentados em contagens com `folegoAckRetryStatus()`, sem IDs ou valores sensíveis.

## Limites / aceitação
- Esta proteção cobre perdas por falha de entrega **após candidato persistido**. Falha antes da persistência impede o cursor de avançar, permitindo replay. Não é uma reconstrução retroativa de todos os 250 eventos históricos, nem prova de conciliação financeira integral.
- A implementação está **somente no GitHub**. A fonte real do editor continua com o bridge anterior e flag desativada, conforme relatório do Work de 14/10/2026. Para instalar é necessária revisão e backup do Apps Script, sem editar outros arquivos de código nem gatilhos.
- O PR #100 segue draft; antes de ativar o ACK é preciso testar isolamento com **dois usuários e dois espaços em backend separado**, rejeição de revisões antigas, comentários com API simulada, unicidade/idempotência do RPC e comparação de versões com o código instalado.
- **Não ativar** `FOLEGO_SHEET_ACK_ENABLED` nesta fase. O usuário deve aprovar explicitamente a ativação após os gates faltantes.
- **Rollback:** flag `false`. A fila é retida para diagnóstico sem modificar o app nem a planilha. Nenhuma transação, fórmula, saldo, gatilho, comentário ou categoria é escrita por esta alteração antes de sua instalação.

## Testes isolados
`node --test qa/staging/folego-ack-pull-bridge.test.mjs qa/staging/folego-ack-retry-queue.test.mjs`

Cobrem flag OFF, conexão interrompida após o cursor, reenvio posterior mesmo sem novos eventos, `already_acknowledged`, resposta com ID errado, versão antiga, conflito de categoria, data/forma divergente, ID duplicado, alteração local, ausência de addon, estouro de quota e backlog cheio. A CI cross-device executa ambas as suites em conjunto.
