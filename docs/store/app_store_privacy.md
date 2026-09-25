# App Store — rascunho de App Privacy

Revisar contra a build final e os SDKs efetivamente enviados.

## Coleta prevista

### Contact Info
**Name**
- finalidade: App Functionality / Account Management.

**Email Address**
- finalidade: App Functionality / Account Management.

### Identifiers
**User ID**
- ID autenticado usado para vincular dados do usuário;
- o mesmo ID pode ser usado como App User ID no RevenueCat;
- finalidade: App Functionality.

### Financial Info
Dados financeiros inseridos no Fôlego, incluindo receitas, despesas, saldos, contas, cartões, dívidas, orçamentos, recorrências, metas e projeções.
- finalidade: App Functionality;
- não destinados a tracking.

### Purchases
RevenueCat processa dados de compras/assinaturas e histórico de compras para validar entitlement, restaurar compras e manter o status Premium.
- finalidade: App Functionality;
- revisar também a finalidade de Analytics indicada pela documentação vigente do RevenueCat.

## Não previstos na v1
- Location;
- Contacts;
- Health & Fitness;
- Photos or Videos;
- Audio Data;
- Browsing History;
- Search History;
- Advertising Data;
- Tracking entre apps/sites;
- Diagnostics de terceiros enquanto não houver SDK de crash reporting.

## Tracking
A v1 não deve habilitar tracking publicitário nem ATT apenas para RevenueCat.

Se futuramente forem adicionados SDKs de atribuição/ads ou identificadores publicitários, esta declaração deve ser refeita.

## URLs
Antes do envio:
- Privacy Policy URL pública e estável;
- Support URL pública e estável;
- opcional: Privacy Choices URL com instruções de exclusão e direitos do usuário.
