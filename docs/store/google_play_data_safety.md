# Google Play — rascunho de Segurança dos dados

Este arquivo é a base para preencher o formulário no Play Console. Deve ser revisado novamente contra a build exata enviada à loja e contra a documentação atual dos SDKs.

## O app coleta dados?
**Sim.**

## O app compartilha dados com terceiros?
A intenção da v1 é **não compartilhar dados para publicidade, venda de dados ou marketing de terceiros**.

Supabase e RevenueCat são usados como prestadores de serviço para autenticação/backend e assinatura. Confirmar no formulário do Google a classificação aplicável a prestadores de serviço no momento do envio.

## Criptografia em trânsito
**Sim.** O app usa serviços acessados por HTTPS/TLS.

## Exclusão de dados
**Sim.** O usuário pode excluir a própria conta pelo Perfil. O fluxo chama a função autenticada de exclusão e remove a conta e os dados associados conforme as regras de retenção aplicáveis.

Também será necessário fornecer uma URL pública de exclusão/privacidade na ficha da loja quando exigido.

## Tipos de dados previstos

### Informações pessoais
**Nome**
- coletado no cadastro;
- finalidade: funcionalidade do app e gerenciamento de conta;
- obrigatório para criação do perfil;
- não usado para anúncios.

**E-mail**
- coletado no cadastro/login;
- finalidade: autenticação, recuperação de acesso e gerenciamento da conta;
- obrigatório para a conta;
- não usado para anúncios.

**ID do usuário**
- ID autenticado do Supabase;
- finalidade: vincular dados financeiros e assinatura ao usuário correto;
- também é usado como App User ID no RevenueCat.

### Informações financeiras
O usuário pode registrar:
- receitas;
- despesas;
- saldos;
- contas;
- cartões;
- faturas;
- benefícios;
- dívidas;
- orçamentos;
- recorrências;
- assinaturas;
- metas;
- projeções;
- descrições e categorias de lançamentos.

Finalidade:
- funcionalidade principal do Fôlego;
- cálculo, organização, planejamento e exibição das finanças do próprio usuário.

Não usar esses dados para publicidade.

### Histórico de compras
RevenueCat processa histórico de compras/assinaturas para:
- confirmar entitlement Premium;
- restaurar compras;
- gerenciar status da assinatura;
- métricas relacionadas à assinatura conforme a configuração do provedor.

A documentação do RevenueCat orienta declarar **Purchase history** no formulário de Segurança dos dados quando o SDK é utilizado.

### Arquivos importados
CSV/OFX podem ser escolhidos pelo usuário para importar lançamentos.
- o arquivo original não deve ser armazenado indefinidamente;
- os registros financeiros extraídos podem ser enviados ao backend para revisão e confirmação;
- revisar a build final para confirmar se o formulário exige também “Files and docs” ou se os dados são adequadamente classificados como informações financeiras.

### Dados que a v1 não pretende coletar
- localização;
- contatos;
- SMS/chamadas;
- fotos/vídeos;
- áudio;
- calendário do dispositivo;
- histórico de navegação;
- saúde/fitness;
- publicidade comportamental;
- crash logs ou analytics de terceiros, enquanto esses SDKs não forem adicionados.

## SDKs que precisam ser rechecados antes da submissão
- Supabase Flutter;
- RevenueCat / purchases_flutter;
- RevenueCat Paywalls / purchases_ui_flutter;
- file_picker;
- share_plus;
- package_info_plus.

Se qualquer SDK mudar o comportamento de coleta, este documento e o formulário do Play Console precisam ser atualizados antes da publicação.
