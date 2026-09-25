# Fôlego 1.0 — checklist de publicação

## Já preparado no repositório
- versão 1.0.0+1;
- package Android `com.caueccipriano.folego`;
- Free/Premium e paywall;
- Trial/Premium por RevenueCat;
- Cortesia/Vitalício no Supabase;
- política de privacidade, termos, suporte e recurso Web de exclusão;
- copy da Google Play e App Store;
- rascunhos Data Safety e App Privacy;
- CI Android/Web e validação de build iOS release sem assinatura;
- QA de entitlement, projeções, recorrências e notificações.

## Dados que precisam existir nas contas das lojas
- nome do desenvolvedor/seller definitivo;
- e-mail público de suporte;
- conta Google Play Developer;
- Apple Developer Program / App Store Connect;
- app criado nas lojas com os identificadores definitivos;
- produtos de assinatura e oferta de teste;
- projeto RevenueCat ligado aos produtos das duas lojas;
- chaves públicas RevenueCat inseridas como secrets/build defines;
- chave de assinatura Android para a build final da Play Store;
- certificados/profiles Apple.

## Google Play
Criar assinatura mensal de R$ 9,90 e configurar oferta de 7 dias grátis, quando permitido pela conta/país.

URLs planejadas após o deploy Web:
- Privacidade: `https://caueccipriano.github.io/folego-app/legal/privacy.html`
- Exclusão de conta: `https://caueccipriano.github.io/folego-app/legal/account-deletion.html`
- Suporte: `https://caueccipriano.github.io/folego-app/legal/support.html`

Preencher Segurança dos dados a partir de `docs/store/google_play_data_safety.md`.

## App Store
Criar assinatura mensal equivalente e oferta introdutória/trial aplicável.

Preencher App Privacy a partir de `docs/store/app_store_privacy.md`.

A tela de exclusão informa que apagar a conta não cancela automaticamente uma assinatura recorrente da loja.

## Antes de apertar Publicar
- build assinada instalada em aparelho Android real;
- build TestFlight instalada em iPhone real;
- compra sandbox;
- restauração de compra;
- expiração de trial;
- usuário Cortesia;
- usuário Vitalício;
- exclusão da conta;
- links legais públicos;
- suporte público funcional;
- screenshots finais sem dados pessoais;
- nenhuma alegação de resultado financeiro garantido.

## Segurança administrativa antes da loja
- publicar `legal_site/` em domínio público independente do repositório;
- validar Política, Termos, Suporte e Exclusão em navegador anônimo;
- tornar `folego-app` privado;
- confirmar que as URLs legais continuam funcionando após a mudança de visibilidade;
- habilitar Leaked Password Protection no Supabase Auth;
- executar nova auditoria Supabase/GitHub;
- manter EN/ES ocultos até a cobertura de interface chegar a 100%.
