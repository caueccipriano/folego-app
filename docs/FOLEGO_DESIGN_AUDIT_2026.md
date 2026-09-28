# Fôlego — revisão visual e de experiência

Status: plano de execução; itens só são concluídos após alteração de código e testes.

## Princípios
- Unbounded em títulos expressivos e indicadores protagonistas; Manrope em corpo, controles, navegação e valores secundários.
- Reservar peso 700 para hierarquia principal. Títulos de cartões em 600, textos corridos em 400, rótulos em 500.
- Nunca comunicar entrada/saída somente por cor; incluir sinal, rótulo ou ícone.
- Não usar texto inferior a 12 px para informação essencial; testar ampliação de texto e contrastes claro/escuro.
- Valores monetários alinhados, sem truncar números relevantes; revisar layouts em 320/375/430 px e desktop.
- Evitar superfícies e divisórias redundantes, mantendo o sistema de raios existente.

## Matriz de revisão por área
| Área | Inspeção e microtarefas | Aceite |
|---|---|---|
| Home | Saldo, fôlego diário, alertas, cards e densidade | Hierarquia nítida, sem overflow em telas compactas |
| Transactions | Filtros, busca, agrupamento por data, sinais e formulário | Registro fácil e valores legíveis |
| Plan | Orçamento, agenda, projeções e explicações | Distinguir realizado, previsto e estimado |
| Wallet | Contas, cartões, faturas, transferências e conciliação | Saldo e vencimentos distinguíveis |
| Profile | Preferências, notificações, privacidade e tema | Controles acessíveis e estados claros |
| Goals | Progresso, valor, prazo, criação e estados vazios | Informações sem depender só de cores |
| Auth/onboarding | Campos, erros, instruções e primeiros passos | Fluxo de entrada compreensível |
| Premium | Benefícios, limites, compra e restauração | Comunicação clara, sem promessas não implementadas |
| Shell/navigation | Tabs, rótulos, ícones, FAB e responsividade | Consistência mobile/tablet/desktop |

## Componentes compartilhados
- [x] Tipografia base: corpo e rótulos ampliados (revisar impacto visual).
- [x] Cabeçalhos de páginas e seções: subtítulos mais legíveis.
- [x] Estados vazios, erros e carregamento: melhor legibilidade.
- [ ] Revisar cartões, chips, inputs, filtros, botões e bottom sheets.
- [ ] Revisar gráficos e cores semânticas nos dois temas.
- [ ] Revisar foco, navegação por teclado, leitor de tela e texto ampliado.

## Validação antes de lançamento
1. Executar Flutter analyze, testes widget e integração.
2. Playwright WebKit iPhone compacto/padrão, Android compacto/padrão, tablet e desktop, tema claro/escuro.
3. Capturar telas e revisar manualmente cortes, contraste, alinhamento e estados vazios/erro.
4. Configurar credenciais de uma conta fictícia para E2E autenticado; não usar credenciais pessoais.
5. Verificar permissões e isolamento de dados no ambiente de desenvolvimento.
6. Não mesclar nem publicar release sem revisão final.
