const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/../FolegoMercadoPagoEmailV353.gs','utf8');
const enc=s=>Buffer.from(s).toString('base64url');
let calls=[],code=200,result={};
const ctx={Date,Math,Object,Number,RegExp,String,Error,isFinite,Array,encodeURIComponent,parseInt,
 ScriptApp:{getOAuthToken:()=> 'DO_NOT_LOG'},UrlFetchApp:{fetch:(url,opts)=>{calls.push({url,opts});return {getResponseCode:()=>code,getContentText:()=>JSON.stringify(typeof result==='function'?result(url):result)}}},
 Utilities:{base64DecodeWebSafe:s=>Array.from(Buffer.from(s,'base64url')),newBlob:b=>({getDataAsString:()=>Buffer.from(b).toString('utf8')})}};
vm.createContext(ctx);vm.runInContext(source,ctx);
let n=0;function t(l,f){f();n++;console.log('PASS',l)}
t('read-only GET with bearer header',()=>{ctx.fmpEmlRestGetV353_('messages?q=test');assert.equal(calls[0].opts.method,'get');assert(!calls[0].url.includes('DO_NOT_LOG'));assert.equal(calls[0].opts.headers.Authorization,'Bearer DO_NOT_LOG')});
t('send and label routes refused',()=>{assert.throws(()=>ctx.fmpEmlRestGetV353_('messages/send'));assert.throws(()=>ctx.fmpEmlRestGetV353_('labels'))});
t('Google 403 fail closed no raw output',()=>{code=403;assert.throws(()=>ctx.fmpEmlRestGetV353_('messages?q=test'),e=>!e.message.includes('DO_NOT_LOG'));code=200});
t('UTF8 plain MIME decoded',()=>assert.equal(ctx.fmpEmlMimeTextV353_({mimeType:'text/plain',body:{data:enc('Você recebeu R$ 370,12')}}),'Você recebeu R$ 370,12'));
t('plain preferred over html, attachment ignored',()=>assert.equal(ctx.fmpEmlMimeTextV353_({parts:[{mimeType:'text/html',body:{data:enc('<p>Wrong</p>')}},{mimeType:'text/plain',body:{data:enc('Right')}},{mimeType:'text/plain',filename:'att.txt',body:{data:enc('Wrong')}}]}),'Right'));
t('HTML fallback strips style script and decodes entities',()=>{const body=ctx.fmpEmlMimeTextV353_({mimeType:'text/html',body:{data:enc('<style>x</style><script>y</script><p>Voc&#234; recebeu&nbsp;R$ 1,00</p>')}});assert(body.includes('Você recebeu R$ 1,00'));assert(!body.includes('script'))});
t('first authentication result header wins',()=>{const msg=ctx.fmpEmlRestMessageV353_({id:'abc',internalDate:'1792146737000',payload:{headers:[{name:'Authentication-Results',value:'first'},{name:'Authentication-Results',value:'second'}]}});assert.equal(msg.getHeader('Authentication-Results'),'first')});
t('pagination follows next token within bound',()=>{let pages=0;result=url=>{if(url.includes('?format=full'))return {id:'m'+pages,internalDate:'1792146737000',payload:{headers:[]}};pages++;return {messages:[{id:'m'+pages}],nextPageToken:pages===1?'next':undefined}};const batch=ctx.fmpEmlRestListV353_();assert.equal(batch.messages.length,2);assert.equal(batch.truncated,false)});
t('perpetual pagination capped and reported',()=>{result=url=>url.includes('?format=full')?{id:'m',internalDate:'1792146737000',payload:{headers:[]}}:{messages:[{id:'m'}],nextPageToken:'more'};const batch=ctx.fmpEmlRestListV353_();assert.equal(batch.messages.length,4);assert.equal(batch.truncated,true)});
t('no GmailApp references',()=>assert(!/GmailApp\./.test(source)));
console.log(n,'Gmail REST tests passed');
