# Fôlego — evolução do aplicativo (13/10/2026)

**Escopo**: Fôlego independente, existente e multiusuário. Não transformar no EU, não recriar o app a partir da branch main e não editar a planilha. Integração com Google Sheets continua compatível e suas regras financeiras permanecem no backend.

**Base real**: `feat/transactions-recurring` (origem do workflow GitHub Pages). O código da `main` é uma base Flutter anterior, com placeholders que não representam o app publicado.

**Legenda**: `BASE` = código da função localizado no projeto, não equivale a teste final no aparelho; `PR` = proposta implementada nesta branch, ainda não publicada; `PENDENTE` = falta implementar ou validar integralmente.

## Fase 1 — Confiabilidade e recursos essenciais
| Item | Estado | Ação para encerrar |
| --- | --- | --- |
| Ícone e instalação PWA no iPhone | PR | SHA nos URLs do ícone e manifest, gerar PNG, QA físico e reinstalação de atalho antigo se necessário |
| Carteira (contas/cartões/faturas/dívidas) | BASE | Testes com dados reais e estados vazios |
| Histórico de Transações + filtros | BASE | Testes regressivos de busca/paginação/períodos |
| Visibilidade da atualização | PR/PENDENTE | Carimbo da leitura Fôlego implementado; **status de sincronização com Sheets não pode ser inferido disso** |
| Categorias/subcategorias | BASE | Validar conflitos e alinhamento com catálogo existente sem reescrever o Apps Script |
| Edição de transações | BASE | Respeitar edição atômica, permissões e IDs estáveis |
| Comentários | BASE | Comparar compatibilidade com comentários existentes |
| Parcelamentos | BASE | Testar fechamento de fatura, próximas parcelas e estornos |
| Antiduplicidade | BASE | Validar fluxo CSV/OFX e quick register, nunca mesclar automaticamente eventos ambíguos |
| Ajustes iPhone/responsividade | BASE/PR | Playwright + QA de teclado, safe areas, PWA e tela física |
| Preservar leitura após falha | PR | Último snapshot válido rotulado como desatualizado, sem inventar sincronização |
| Isolamento ao mudar espaço financeiro | PR | Descartar respostas atrasadas e zerar estado de espaço anterior |

## Fase 2 — Inteligência financeira
| Item | Estado | Ação para encerrar |
| --- | --- | --- |
| Autopilot/classificação por regras | BASE | Só aplicar automaticamente regras determinísticas e auditáveis; manter revisão em ambiguidade |
| Caixa de entrada de classificação | BASE | Testar pendências e navegação |
| Resumo financeiro/Home | BASE | Monitorar consistência sem recálculo contábil no cliente |
| Agenda/calendário | BASE | Testar recorrências, dívidas e faturas |
| Simulação de compra | BASE | Validar o simulador/projeção e evitar dupla contagem de parcelas |
| Orçamentos por categoria | BASE | Verificar períodos, limites e alertas |
| Metas de economia | BASE | Conferir contribuições e saldo de metas |
| Projeções futuras | BASE | Validar premissas e incertezas |
| Insights personalizados | BASE | Não inventar fatos ou notificações financeiras |
| Evolução/relatório mensal | BASE | Verificar competência x caixa e meses encerrados |

## Fase 3 — Acabamento e recursos avançados
| Item | Estado | Ação para encerrar |
| --- | --- | --- |
| Registro ultrarrápido | BASE | Testar débito, crédito, PIX e transferência |
| Busca inteligente | BASE | Filtro por descrição, data, valor e categoria |
| Notificações úteis | BASE/PENDENTE | Fluxo web presente; iOS/Android nativo depende de targets físicos e permissões |
| Importação de extratos | BASE/PENDENTE | CSV/OFX presentes; PDF bancário não confirmado |
| Offline seguro | PENDENTE | Exigir política de conflitos/idempotência, criptografia e isolamento antes de gravar offline |
| Biometria e privacidade | BASE/PENDENTE | Ocultar valores existe; biometria real depende do ambiente/dispositivo |
| Temas e personalização | BASE | Claro/escuro presentes; validação visual final |
| Onboarding intuitivo | BASE | Testar retomada sem duplicar setup |
| Ajuda de instalação iPhone | PR | Passo a passo no Perfil, sem prometer atualização automática de atalho existente |
| Performance e regressões | BASE/PR | `flutter analyze`, testes Flutter, Playwright, build e publicação com gates |

## Critérios mínimos para considerar **publicado**
1. `flutter analyze`, testes de integridade/UI e build Web verdes.
2. QA do fluxo financeiro existente em uma conta de teste, sem reproduzir nem alterar registros reais.
3. Nenhum dado de outro `space_id` reaparece depois de troca de espaço.
4. Nenhum evento, categoria, saldo, comentário, fatura ou transação é modificado por esta mudança visual.
5. No iPhone, validar manualmente o ícone e a experiência instalada; atualizar o site não troca necessariamente ícones de atalhos antigos.
6. Publicação somente a partir da branch atualmente responsável pelo GitHub Pages, após revisão dos checks.

**Nesta entrega**: somente carimbo de consulta, retenção do último snapshot, proteção de troca de espaço, sanitização de erros, links versionados de ícone/manifest e ajuda de instalação. Nenhuma alteração de banco ou planilha.
