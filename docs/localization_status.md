# Idiomas — status da v1

## Produção
A v1 deve ser publicada somente em **Português (Brasil)** enquanto ainda houver textos de interface hardcoded em português.

Isso evita uma experiência híbrida em que menu e navegação aparecem em inglês/espanhol, mas telas internas continuam em português.

## Workspace já preparado
Os catálogos existem para:
- Português (Brasil)
- English
- Español

A infraestrutura de Locale também já existe. Inglês e espanhol permanecem deliberadamente ocultos em `productionSupportedLocales`.

## Regra para liberar um idioma
Só incluir EN ou ES em `productionSupportedLocales` quando:
1. autenticação e recuperação estiverem localizadas;
2. onboarding e primeira configuração estiverem localizados;
3. Home, Lançamentos, Plano, Carteira e Perfil estiverem localizados;
4. paywall, assinatura, erros, estados vazios e diálogos estiverem localizados;
5. datas/moeda/formatação tiverem sido verificadas no locale;
6. testes de widget cobrirem a troca de idioma;
7. não houver texto funcional misturado em português no caminho principal.

## Proteção automática
`test/localization_release_guard_test.dart` garante que os arquivos ARB mantenham as mesmas chaves e que idiomas ainda incompletos não sejam expostos por engano.

## Progresso da migração
Concluído no workspace PT-BR/EN/ES:
- shell/navegação principal;
- onboarding;
- primeiro uso;
- autenticação visual principal;
- paywall/tela Premium.

Ainda pendente antes de liberar EN/ES:
- validações e mensagens de erro de autenticação;
- Home após configuração;
- Lançamentos;
- Plano;
- Carteira;
- Perfil e configurações;
- notificações e fluxos secundários;
- revisão final de moeda, datas e pluralização.

EN/ES continuam deliberadamente fora de `productionSupportedLocales` até esse checklist chegar a 100%.
