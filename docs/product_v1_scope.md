# Fôlego v1 — escopo fechado

## Proposta
Fôlego responde primeiro à pergunta: **quanto eu posso gastar hoje sem apertar amanhã?**

A v1 mantém o núcleo financeiro útil no plano gratuito e cobra pelos fluxos que ampliam planejamento ou reduzem trabalho manual.

## Fôlego Free
- Home com Fôlego diário e resumo financeiro.
- Lançamentos manuais de entrada e saída.
- Histórico e filtros.
- Planejamento mensal.
- Carteira com contas, cartões, benefícios e dívidas.
- Recorrências e assinaturas.
- Metas e diário financeiro.
- Lembretes financeiros essenciais.
- Categorias, tema, conta, privacidade e exclusão da conta.

## Fôlego Premium
Preço de lançamento: **R$ 9,90/mês**.
Oferta planejada: **7 dias grátis**.

Desbloqueia:
- projeções e cenários futuros;
- automações de classificação;
- importação de extratos CSV/OFX;
- exportação dos dados em CSV;
- capabilities de notificações avançadas já previstas na arquitetura.

## Entitlements
A fonte de verdade de compras é o entitlement `premium` do RevenueCat.

Estados suportados:
- Free;
- Trial;
- Premium;
- Cortesia, com validade opcional;
- Vitalício.

Cortesias e vitalício ficam em `premium_grants`, tabela sem acesso direto para o cliente. O app consulta somente `get_my_premium_grant()`, que retorna a concessão ativa do próprio usuário autenticado.

## Dependências da loja
Só ficam para a etapa de publicação:
- cadastrar o produto mensal de R$ 9,90;
- configurar os 7 dias grátis;
- conectar as chaves públicas do RevenueCat;
- signing e AAB/Archive;
- URLs públicas finais de Política de Privacidade, Termos e Suporte;
- teste fechado e revisão exigidos pela Google Play.

Sem uma loja configurada, a build continua funcional como Free e reconhece cortesias/vitalício concedidos pelo backend.
