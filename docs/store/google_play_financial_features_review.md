# Fôlego — enquadramento para Google Play (revisão pré-cadastro)

Status: **rascunho técnico, sujeito à avaliação do Google Play** (25/09/2026).
Não abrir/pagar uma conta na suposição de que um app de finanças é
automaticamente elegível a uma conta de pessoa física.

## Fatos sobre a versão atual a conferir na build enviada
- Aplicativo de registro manual e planejamento de orçamento **pessoal**.
- Receitas, despesas, cartões (registro de fatura), dívidas (registro e previsão),
  metas, relatórios e projeções são **dados inseridos pelo usuário**.
- Não custodia saldo, emite cartão, efetua pagamentos, oferece empréstimos,
  movimenta dinheiro, executa investimentos ou presta consultoria financeira.
- Premium é assinatura de **software**, cobrada pela loja por meio da integração
  técnica RevenueCat. Não confundir a compra do app com movimentação financeira
  entre usuários.

Se o produto ganhar integração bancária, crédito, investimentos ou recomendações
financeiras individuais, refazer integralmente esta classificação.

## Tipo de conta (decisão ainda não tomada)
O Google permite monetização tanto para contas pessoais quanto organizações,
mas exige conta de organização para **produtos e serviços financeiros**.
A página oficial não resolve explicitamente o caso restrito de **controle
manual de orçamento**, que não presta serviço bancário nem transaciona dinheiro.

**Ação antes do cadastro:** confirmar com a orientação do Play Console/suporte
se o produto, nas condições acima, pode ser distribuído em uma conta pessoal;
guardar a resposta. Se a classificação exigir organização, interromper
cadastro pessoal e planejar a estrutura empresarial e D-U-N-S. Nunca escolher
"sem recursos financeiros" apenas para contornar essa regra.

Fonte: https://support.google.com/googleplay/android-developer/answer/13634885?hl=pt-BR

## Declaração obrigatória de recursos financeiros
Todos os apps distribuídos pelo Google Play, inclusive em testes fechados,
precisam preencher a declaração. As opções oficiais incluem "Outro" e
"Meu app não oferece recursos financeiros"; não é possível fixar a opção sem
a descrição funcional definitiva e a classificação correspondente.

Rascunho explicativo (adaptar conforme o formulário e resposta do Google):
> Aplicativo de organização de orçamento pessoal, com lançamento manual de
> receitas, despesas, contas, compromissos, cartões e planejamento financeiro.
> Não fornece conta bancária, carteira de pagamentos, crédito, seguros,
> gestão de ativos, recomendação de investimentos ou movimentação de valores.

Fonte: https://support.google.com/googleplay/android-developer/answer/13849271?hl=pt-BR

## Segurança dos dados (não confundir com recursos financeiros)
O Fôlego trata dados financeiros inseridos pelos usuários, nome, e-mail,
identificador de usuário e estado de compra/assinatura. Revisar item a item
contra a build final e os SDKs antes de responder ao formulário.
Rascunho de campos: `docs/store/google_play_data_safety.md`.

## Campos administrativos ainda dependentes do responsável
- Nome público do desenvolvedor/seller definitivo (não inferir do GitHub).
- E-mail **público** de suporte; não usar e-mail pessoal sem decisão explícita.
- Confirmação da classificação do Google para app manual de orçamento.
- Conta Play Console e perfil de pagamentos verificados.
- Oferta mensal de R$ 9,90/7 dias grátis realmente ativada na loja, se elegível.
- Chave pública RevenueCat específica da Google Play como secret de build;
  a chave `test_` é exclusivamente para APK de desenvolvimento.
