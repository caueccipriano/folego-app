const fs=require('fs'), vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/../FolegoMercadoPagoEmailV353.gs','utf8');
const ctx={Date,Math,Object,Number,RegExp,String,Error,isFinite};vm.createContext(ctx);vm.runInContext(source,ctx);
let tests=0;function t(label,cb){cb();tests++;console.log('PASS',label)}
const parse=(s,b)=>ctx.fmpEmlParseV353_(s,b,new Date('2026-10-16T10:32:00Z'));
t('CLARO payment parsed',()=>{const a=parse('Seu Pix foi enviado','Seu Pix de R$ 56,01 foi enviado Sexta-feira, 16 de outubro de 2026, às 07:32:17. CLARO S A CPF/CNPJ: xx.x32.544/0001-xx Itaú Unibanco S.A.');assert.equal(a.amount,56.01);assert.equal(a.direction,'out')});
t('Jeferson receipt 635 parsed exactly, not 634.20',()=>{const a=parse('Seu Pix foi enviado','Seu Pix de R$ 635 foi enviado Quinta-feira, 15 de outubro de 2026, às 19:07:31. Jeferson Felipe da Silva CPF/CNPJ: 36.036.078/0001-03');assert.equal(a.amount,635);assert.equal(a.direction,'out')});
t('incoming receipt',()=>{const a=parse('Seu Pix foi recebido','Seu Pix de R$ 370,12 foi recebido');assert.equal(a.amount,370.12);assert.equal(a.direction,'in')});
t('large decimal',()=>assert.equal(parse('Seu Pix foi enviado','Seu Pix de R$ 1.234,56 foi enviado').amount,1234.56));
t('rejected email no transaction',()=>assert.equal(parse('Não foi possível fazer o depósito','Por favor, tente novamente mais tarde'),null));
t('marketing no transaction',()=>assert.equal(parse('Novo Cofrinho','Nova vantagem disponível para você'),null));
t('unrecognized money no transaction',()=>assert.equal(parse('Promoção','Você ganhou R$ 50'),null));
t('authorized sender',()=>assert.equal(ctx.fmpEmlAllowedSenderV353_('Mercado Pago <notificacoes@mercadopago.com.br>'),true));
t('different sender rejected',()=>assert.equal(ctx.fmpEmlAllowedSenderV353_('phish@mercadopago.com.br.fake.io'),false));
t('missing amount',()=>assert.equal(parse('Seu Pix foi enviado','Seu Pix de R$ -- foi enviado'),null));
t('invalid date fallback',()=>assert.equal(parse('Seu Pix foi enviado','Seu Pix de R$ 0,01 foi enviado').amount,0.01));
console.log(tests,'tests passed');
