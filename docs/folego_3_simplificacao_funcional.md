# FÔLEGO 3.0 — simplificação funcional (sem empobrecer os visuais)

## Decisão de produto

O FÔLEGO deve calcular e classificar sem exigir que a pessoa administre o aplicativo. A navegação cotidiana se resume a **Hoje**, **Movimentos** e **Futuro**. Gráficos, projeções, detalhes e comparativos permanecem ricos e exploráveis.

## Experiência principal

| Destino | Pergunta que responde | Funcionalidades que passam a viver juntas |
| --- | --- | --- |
| Hoje | Quanto posso gastar até receber? | Saldo livre, fôlego diário, próximos compromissos, registrar uma movimentação, alertas realmente acionáveis |
| Movimentos | O que aconteceu com o meu dinheiro? | Linha do tempo, busca, conciliação, cartões, assinaturas, importação e correção contextual |
| Futuro | Se eu fizer algo, o que acontece? | Projeções, orçamento, simular compras, meses futuros, avanço das metas |

**Contas, cartões, dívidas, metas, diário, perfil, automações e ajustes** continuam disponíveis como recursos secundários. Nenhum dado é descartado.

## Prioridade: reduzir tarefas, não métricas

1. **Menos cadastros:** preencher automaticamente categoria, conta e recorrência quando a confiança e os dados permitirem; deixar a correção contextual ao movimento.
2. **Menos revisão manual:** mostrar pendências apenas quando houver impacto financeiro ou ambiguidade; não exigir check-in diário.
3. **Um só lugar para cada pergunta:** eliminar caminhos duplicados entre Planejamento, Carteira, Visão Geral e relatórios, preservando a análise detalhada sob toque.
4. **Simulação sem formulário longo:** partir do valor da compra e permitir abrir parcelas/datas apenas quando necessário.
5. **Recompensas informativas:** mostrar quanto já foi preservado, objetivos e melhorias reais, sem contadores artificiais nem notificações para forçar uso.
6. **Importação invisível quando confiável:** conciliação protegida, jamais criar/alterar valores em silêncio quando houver incerteza.

## Entregas por fase

- **Fase 1 — em branch de desenvolvimento:** três destinos principais em celular e desktop; acesso secundário a contas/cartões/dívidas, metas, diário, perfil/automações/ajustes; rotas de notificação e cálculos existentes preservados.
- **Fase 2 — consolidar funcionalidades:** redirecionar entradas duplicadas e simplificar a classificação e o lançamento rápido, sem alterar o motor financeiro.
- **Fase 3 — piloto automático seguro:** usar integrações e regras já existentes para diminuir tarefas recorrentes, com opt-in, revisão de exceções e auditoria.
- **Fase 4 — prazer de uso:** insights dinâmicos e simulação fluida dentro dos cards existentes, com testes de acessibilidade, privacidade e responsividade.

## Guardrails

- Stack permanece **Flutter/Dart + Supabase**, sem reescrita.
- Não modificar registros, projeções oficiais, RLS, regras de importação, pagamentos, faturas, parcelas ou saldos como parte da mudança de navegação.
- Manter as rotas /wallet e /profile para notificações/links já emitidos.
- Nunca publicar antes de validar testes de navegação, contas, troca de espaço e privacidade no pipeline.
- Preservar telas avançadas até que suas substitutas comprovadamente cubram as mesmas necessidades.
