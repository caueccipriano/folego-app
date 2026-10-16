const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/../FolegoMercadoPagoEmailV353.gs','utf8');
let writes=0,delivered=[],locked=0,validationWrites=0,lastUpdatedRow=null;
const rule={getCriteriaType:()=> 'LIST',getCriteriaValues:()=>[['Recebido','Processado'],false],copy:()=>({requireValueInList:(values,dropdown)=>({build:()=>({values,dropdown,allowInvalid:false,help:'original'})})})};
let appliedRule=null;const fakeSheet={getRange:(row,col)=>{assert.equal(col,11);return {getDataValidation:()=>rule,setDataValidation:r=>{validationWrites++;appliedRule=r}}}};
const cfg={SPREADSHEET_ID:'sheet',TZ:'America/Sao_Paulo',INPUT_STATUS:{RECEIVED:'Recebido'},SHEETS:{INPUT:'Entrada Automacao'}};
const good={getFrom:()=> 'Mercado Pago <notification@mercadopago.com.br>',getHeader:()=> 'mx.google.com; dmarc=pass header.from=mercadopago.com.br',getId:()=> 'msg1',getSubject:()=> 'Seu Pix foi enviado',getPlainBody:()=> 'Seu Pix de R$ 635 foi enviado Quinta-feira, 15 de outubro de 2026, às 19:07:31. Jeferson Felipe da Silva CPF/CNPJ: 36.036.078/0001-03',getDate:()=>new Date('2026-10-15T22:07:31Z')};
let messages=[good],seen=false,transportError=false;
const ctx={Date,Math,Object,Number,RegExp,String,Error,isFinite,CFG_V3:cfg,
 Utilities:{parseDate:(v,tz)=>{assert.equal(tz,'America/Sao_Paulo');const m=v.match(/(\d+)\/(\d+)\/(\d+) (.*)/);return new Date(`${m[3]}-${m[2]}-${m[1]}T${m[4]}-03:00`)},formatDate:()=> '15/10/2026 19:07:31'},
 LockService:{getScriptLock:()=>({tryLock:()=>{locked++;return true},releaseLock:()=>locked--})},
 SpreadsheetApp:{DataValidationCriteria:{VALUE_IN_LIST:'LIST'},openById:()=>({getSheetByName:name=>{assert.equal(name,'Entrada Automacao');return fakeSheet}})},GmailApp:{search:()=>[{getMessages:()=>messages}]},
 sha256V3_:x=>'hash:'+x,findInputByHashV3_:()=>seen === true ? {row:5,status:'RevisaoEmail'} : seen,
 findMercadoPagoExistingV352_:()=>({}),appendInputLogV3_:()=>{writes++;return 1},updateInputLogV3_:(_s,_r,data)=>{lastUpdatedRow=_r;assert.equal(data.status,'RevisaoEmail');writes++},
 _folegoSyncApi_:body=>{if(transportError)throw Error('SECRET');delivered.push(body);return {ok:true,receipts:[{status:'needs_review',review_status:'needs_review',review_reason:'value_mismatch'}]}}
};vm.createContext(ctx);vm.runInContext(source,ctx);
ctx.fmpEmlRestListV353_=()=>({messages,truncated:false});
let n=0;function t(label,f){f();n++;console.log('PASS',label)}
t('São Paulo receipt date exact',()=>assert.equal(ctx.fmpEmlParseV353_(good.getSubject(),good.getPlainBody(),good.getDate()).date.toISOString(),'2026-10-15T22:07:31.000Z'));
t('recipient extracted',()=>assert.equal(ctx.fmpEmlParseV353_(good.getSubject(),good.getPlainBody(),good.getDate()).recipient,'Jeferson Felipe da Silva'));
t('rejected subject defeats quoted success',()=>assert.equal(ctx.fmpEmlParseV353_('Pix recusado',good.getPlainBody(),good.getDate()),null));
t('both directions fail closed',()=>assert.equal(ctx.fmpEmlParseV353_('Pix','Seu Pix de R$ 1 foi enviado Seu Pix de R$ 2 foi recebido',good.getDate()),null));
t('DMARC failure rejected',()=>assert.equal(ctx.fmpEmlAuthenticatedV353_({getHeader:()=> 'mx.google.com; dmarc=fail header.from=mercadopago.com.br'}),false));
t('forged authentication header rejected',()=>assert.equal(ctx.fmpEmlAuthenticatedV353_({getHeader:()=> 'attacker.com; dmarc=pass header.from=mercadopago.com.br'}),false));
t('aligned authentication accepted',()=>assert.equal(ctx.fmpEmlAuthenticatedV353_(good),true));
t('dry-run writes nothing',()=>{ctx.folegoEmailMercadoPagoDryRunV353();assert.equal(writes,0);assert.equal(delivered[0].dry_run,true)});
t('write mode only staging and isolated log',()=>{const r=ctx.folegoCapturarEmailsMercadoPagoV353();assert.equal(r.writes,1);assert.equal(writes,2);assert.equal(delivered[1].action,'capture_receipts')});
t('receipt idempotence',()=>{seen=true;const before=writes;const r=ctx.folegoCapturarEmailsMercadoPagoV353();assert.equal(r.alreadySeen,1);assert.equal(writes,before);seen=false});
t('transport failure leaves receipt unacknowledged and releases lock',()=>{transportError=true;const before=writes;assert.throws(()=>ctx.folegoCapturarEmailsMercadoPagoV353(),e=>!e.message.includes('SECRET'));assert.equal(writes,before);assert.equal(locked,0);transportError=false});
t('unverified mail ignored without write',()=>{messages=[{...good,getHeader:()=>''}];const before=writes;assert.equal(ctx.folegoCapturarEmailsMercadoPagoV353().relevant,0);assert.equal(writes,before)});
t('end-to-end identifier extracted',()=>{const p=ctx.fmpEmlParseV353_('Pix',good.getPlainBody()+' Identificador: E12345678202610151907abcdefghijklmnop',good.getDate());assert.equal(p.providerTransactionId,'E12345678202610151907abcdefghijklmnop')});
t('no financial mutators, no gmail labels, no send',()=>{assert(!/GmailApp\.(sendEmail|createLabel)|appendLaunch|createFinancialEvent|\.rpc\(/.test(source))});
t('validation copies allowed options dropdown and unrelated restrictions',()=>{assert.deepEqual(appliedRule.values,['Recebido','Processado','RevisaoEmail']);assert.equal(appliedRule.dropdown,false);assert.equal(appliedRule.allowInvalid,false);assert.equal(appliedRule.help,'original')});
t('received retry reuses row without append',()=>{messages=[good];seen={row:275,status:'Recebido'};const before=writes;ctx.folegoCapturarEmailsMercadoPagoV353();assert.equal(lastUpdatedRow,275);assert.equal(writes,before+1);seen=false});
t('dry-run never edits validation or existing received row',()=>{seen={row:275,status:'Recebido'};const before=writes,vbefore=validationWrites;ctx.folegoEmailMercadoPagoDryRunV353();assert.equal(writes,before);assert.equal(validationWrites,vbefore);seen=false});
console.log(n,'safety tests passed');
