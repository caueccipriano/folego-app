# OBSOLETO — NÃO PUBLICAR NEM MESCLAR ESTA BRANCH

Este rascunho de auditoria é **substituído** pelo candidato comercial integrado de [PR #9](https://github.com/caueccipriano/folego-app/pull/9), já em teste na branch `qa/premium-native-integration-20260925`.

A branch `qa/folego-v1-merge-20260925` foi criada sobre um `base_sha` antigo do snapshot da PR3 (484553c), enquanto a base ativa avançou até 90bb3fb. Ela **não** representa a versão mais recente da PWA e não deve ser usada para deploy, CI de release ou merge. Nenhum deploy foi disparado por esta branch.

A PR #9 é a fonte atual de QA, com checks por commit exato. A PR3 permanece draft e com conflitos. Nenhuma delas deve ser publicada antes do sucesso dos checks obrigatórios e da verificação dos pagamentos sandbox.

Este arquivo existe para registrar o cuidado e evitar retrabalho ou a promoção acidental de uma branch obsoleta.
