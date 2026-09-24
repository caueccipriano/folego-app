# Fôlego v1 — plano de QA de release

## Gate automatizado
A release não deve avançar enquanto algum item crítico abaixo falhar:

- `flutter analyze`;
- testes de entitlement Premium;
- regressão de projeções;
- regressão de recorrências;
- regressão de notificações/automações;
- build Web release;
- geração do scaffold nativo;
- compilação Android;
- auditoria da suíte legada e triagem das falhas.

## Matriz de acesso

### Free
- app abre normalmente;
- lançamentos manuais funcionam;
- carteira e planejamento mensal funcionam;
- lembretes essenciais funcionam;
- projeção abre paywall;
- importação CSV/OFX abre paywall;
- automações abrem paywall;
- exportação CSV abre paywall.

### Trial
- mesmas permissões do Premium;
- rótulo informa teste ativo;
- expiração volta para Free quando entitlement deixa de estar ativo.

### Premium
- recursos pagos abrem diretamente;
- restaurar compras atualiza o entitlement;
- gerenciamento de assinatura abre o Customer Center quando configurado.

### Cortesia
- acesso Premium funciona sem compra na loja;
- data de validade é respeitada;
- usuário não consegue conceder a si próprio uma cortesia pelo cliente.

### Vitalício
- acesso Premium permanece ativo sem data de expiração.

## Jornada de usuário
1. criar conta;
2. confirmar e-mail;
3. concluir ou pular onboarding;
4. cadastrar conta financeira;
5. cadastrar entrada recorrente;
6. registrar despesa;
7. conferir Home;
8. criar orçamento;
9. criar recorrência;
10. abrir Carteira;
11. abrir Agenda;
12. criar meta;
13. tentar recurso Premium como Free;
14. voltar sem comprar e confirmar que o app segue funcional;
15. ativar entitlement de teste;
16. repetir recursos Premium;
17. sair e entrar novamente;
18. reinstalar e restaurar compra;
19. excluir a conta.

## Android físico
Validar pelo menos:
- teclado e campos;
- safe areas;
- botão voltar;
- deep links de autenticação;
- file picker CSV/OFX;
- compartilhamento/exportação CSV;
- permissões de notificações;
- background/resume;
- rotação, se suportada;
- telas pequenas e fonte aumentada.

## Privacidade e segurança
- sem dados financeiros em logs;
- sem e-mail/token/JWT em logs;
- RLS ativa nas tabelas expostas;
- conta excluível pelo usuário;
- política de privacidade pública antes de teste fechado;
- proteção de senha vazada habilitada antes da produção;
- revisar SDKs no formulário de Segurança dos dados.

## Critério para RC 1.0.0
- nenhum bug crítico ou alto conhecido;
- Android compila;
- fluxos Free/Premium passam;
- políticas e suporte têm URLs públicas finais;
- assets da loja finalizados;
- assinatura/RevenueCat testados em sandbox;
- build instalada e testada em aparelho Android real.
