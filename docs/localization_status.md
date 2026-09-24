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

## Próxima sequência de migração
1. onboarding e first-use;
2. autenticação;
3. paywall Premium;
4. shell/navegação;
5. Home;
6. Lançamentos;
7. Plano;
8. Carteira;
9. Perfil e configurações;
10. mensagens de erro e fluxos secundários.
