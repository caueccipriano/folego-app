# FÔLEGO Sync 2.0 — publicação segura pelo GitHub

**Status: automação preparada no GitHub.** Instalação no Apps Script real depende de uma autorização Google via OAuth e dos testes da instância real. **Este workflow NÃO ativa o ACK.**

## O que o workflow faz

1. Valida a sintaxe dos três módulos e executa testes sintéticos de conflitos, readback e recuperação do ACK.
2. Na operação **remote-audit**, lê o código do Apps Script real sem gravar nada.
3. Na operação **install**, recupera todos os arquivos instalados, preserva o manifesto e o Web App V3.3 e substitui só três módulos: FolegoSync, FolegoRowAck e FolegoAckRetry.
4. Faz verificações contra edição concorrente, gera uma versão imutável de backup no próprio Google Apps Script antes de gravar e verifica o código de todos os arquivos após a instalação.
5. Não faz redeploy do Web App, não cria gatilhos, não mexe nas Script Properties, não altera saldos, comentários nem transações.

**Justificativa técnica:** a API Google Apps Script projects.updateContent substitui **todos** os arquivos. Atualizar o projeto com somente três arquivos apagaria o restante. Por isso, o instalador preserva todo o conteúdo remoto antes de chamar a API, abortando diante de conflitos ou arquivos originais não identificados.

## Executar

No GitHub, abra **Actions → Folego Sync 2.0 - Apps Script safe rollout → Run workflow** e selecione:

- **validate**: testes locais de segurança, sem acesso ao Google.
- **remote-audit**: auditoria remota somente leitura, após OAuth.
- **install**: instalação de fonte no projeto existente (não ativa o ACK).

A opção padrão é validate e não há execução automática em produção após merge. O job de Google usa o ambiente folego-apps-script-production. Recomenda-se configurar proteção de revisor em Settings → Environments antes da primeira execução install.

## Autorização Google — feita uma única vez, sem TinyFish

O login do Google Drive conectado no ChatGPT e o Safari não fornecem credenciais para Actions. O único segredo esperado é o GitHub Actions secret **CLASPRC_JSON**. Nunca envie esse segredo no chat, em e-mail ou em arquivo do repositório.

1. Habilite a **Apps Script API** em https://script.google.com/home/usersettings.
2. Em um computador próprio ou terminal confiável, use clasp 3.4.1: comando npx @google/clasp@3.4.1 login.
3. Copie o conteúdo gerado no arquivo ~/.clasprc.json para **GitHub → Settings → Secrets and variables → Actions → New repository secret**, com nome exato **CLASPRC_JSON**.
4. Confirme que a conta Google tem acesso ao projeto Apps Script cujo ID é 1UByBukssmkEy__94vG02_hsJ4m8la52Ek2FaWZrO96jLihYB891uyHU5.
5. Execute primeiro remote-audit e confira seu resultado. Depois da inspeção das diferenças, execute install.

Compatível com formato clasp v3 (tokens.default com client_id/client_secret/refresh_token) ou formato legado local (oauth2ClientSettings + token.refresh_token). A credencial fica oculta na configuração Secrets do GitHub.

## O que continua pendente

- Executar as ações GitHub e confirmar os testes reais.
- Validar o ciclo planilha ↔ FÔLEGO com dois usuários/ambientes isolados, incluindo repetição, falhas, categoria local editada, parcelas, comentários e ausência de duplicatas.
- Validar folegoSyncStatus e folegoAckRetryStatus.
- **Obter aprovação explícita do usuário ANTES** de habilitar FOLEGO_SHEET_ACK_ENABLED=true na instância real.

## Recuperação

O job install imprime apenas o número da versão **pré-instalação**. Essa versão é imutável e pode ser restaurada pela Apps Script API, mantendo os arquivos históricos. Em incidente, mantenha o ACK desligado e restaure a versão anterior. Não exclua automaticamente a versão de backup.

Referências: https://developers.google.com/apps-script/api/reference/rest/v1/projects/updateContent
https://developers.google.com/apps-script/api/reference/rest/v1/projects.versions/create
https://developers.google.com/apps-script/guides/clasp
