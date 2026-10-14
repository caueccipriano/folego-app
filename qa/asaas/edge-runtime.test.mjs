import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';

const token='sandbox_test_token_'.repeat(3);
const link={id:'link_folego',url:'https://sandbox.asaas.com/c/folego',active:true,chargeType:'RECURRENT',subscriptionCycle:'MONTHLY',value:9.90};
const subscription={id:'sub_test',customer:'cus_test',cycle:'MONTHLY',value:9.90,paymentLink:link.id,status:'ACTIVE'};
const payment={id:'pay_test',subscription:'sub_test',customer:'cus_test',status:'CONFIRMED',value:9.90,dueDate:'2026-10-14',paymentLink:link.id};
function runtime(name, options={}) {
 const writes=[],calls=[];
 let handler;
 const env={SUPABASE_URL:'https://test.supabase.co',SUPABASE_ANON_KEY:'test-public',SUPABASE_SERVICE_ROLE_KEY:'test-server',FOLEGO_ASAAS_SANDBOX_API_KEY:token,FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_ID:link.id,FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_URL:link.url,FOLEGO_ASAAS_SANDBOX_WEBHOOK_TOKEN:token,FOLEGO_ASAAS_SANDBOX_CHECKOUT_ENABLED:'true',FOLEGO_ASAAS_SANDBOX_WEBHOOK_ENABLED:'true',...options.env};
 const subscriptions=options.subscriptions??[];
 const intents=options.intents??[{user_id:'user_a',plan:'monthly',expires_at:'2099-01-01T00:00:00Z'}];
 const events=new Map();
 const fetch=async (url,init={})=>{
  url=String(url);calls.push(url);
  const u=new URL(url);let result;
  if(u.pathname==='/auth/v1/user')result=options.user??{id:'user_a',email:'a@example.test',email_confirmed_at:'2026-01-01'};
  else if(u.hostname==='api-sandbox.asaas.com') {
   if(options.apiFailure)return Response.json({error:'unavailable'},{status:503});
   if(u.pathname.startsWith('/v3/paymentLinks/'))result={...link,...options.link};
   else if(u.pathname.endsWith('/payments'))result={data:options.payments??[payment],hasMore:false};
   else if(u.pathname.startsWith('/v3/subscriptions/'))result={...subscription,...options.subscription};
   else if(u.pathname.startsWith('/v3/customers/'))result={email:'a@example.test'};
   else throw Error('unexpected Asaas path '+url);
  } else if(u.pathname.startsWith('/rest/v1/')) {
   const table=u.pathname.split('/').at(-1);
   if(init.method==='POST'||init.method==='PATCH'){
    const value=JSON.parse(init.body);writes.push({table,value});
    if(table==='folego_asaas_events')events.set(value.event_id,value);
    if(table==='folego_asaas_subscriptions'){
      const old=subscriptions.findIndex(x=>x.subscription_id===value.subscription_id);
      if(old<0)subscriptions.push(value);else subscriptions[old]=value;
    }
    return new Response(null,{status:204});
   }
   if(table==='premium_grants')result=options.grants??[];
   else if(table==='folego_asaas_billing_intents')result=intents;
   else if(table==='folego_asaas_subscriptions')result=subscriptions;
   else throw Error('unexpected DB table '+url);
  } else throw Error('network destination not allowed '+url);
  return Response.json(result);
 };
 const source=readFileSync(new URL('../../supabase/functions/'+name+'/index.ts',import.meta.url),'utf8');
 vm.runInNewContext(stripTypeScriptTypes(source),{Deno:{env:{get:k=>env[k]},serve:h=>handler=h},fetch,Response,Request,URL,TextEncoder,crypto,Date,Set,console});
 const call=async(body={id:'evt_test',event:'PAYMENT_CONFIRMED',payment:{id:'pay_test',subscription:'sub_test'}},headers={'asaas-access-token':token})=>handler(new Request('https://test.invalid',{method:'POST',headers,body:JSON.stringify(body)}));
 return {call,writes,calls,subscriptions,events};
}
const webhook='folego-asaas-webhook-sandbox';
const checkout='folego-asaas-checkout-sandbox';
test('locked webhook makes no network requests or writes',async()=>{const r=runtime(webhook,{env:{FOLEGO_ASAAS_SANDBOX_WEBHOOK_ENABLED:'false'}});assert.equal((await r.call()).status,503);assert.equal(r.calls.length,0);});
test('invalid webhook token makes no requests',async()=>{const r=runtime(webhook);assert.equal((await r.call(undefined,{'asaas-access-token':'wrong'})).status,401);assert.equal(r.calls.length,0);});
test('confirmed API receipt creates only isolated sandbox entitlement',async()=>{const r=runtime(webhook);assert.equal((await r.call()).status,200);assert.equal(r.subscriptions[0].user_id,'user_a');assert.equal(r.subscriptions[0].paid_until,'2026-11-14T00:00:00.000Z');assert.equal(r.subscriptions[0].environment,'sandbox');assert.ok(r.writes.every(w=>w.table.startsWith('folego_asaas_')));});
for(const status of ['PENDING','OVERDUE','REFUNDED','CHARGEBACK_REQUESTED','CHARGEBACK_DISPUTE','AWAITING_CHARGEBACK_REVERSAL'])test(status+' never grants paid period',async()=>{const r=runtime(webhook,{payments:[{...payment,status}]});await r.call();assert.equal(r.subscriptions[0].paid_until,null);});
test('duplicate webhook produces one subscription and one event',async()=>{const r=runtime(webhook);await r.call();await r.call();assert.equal(r.subscriptions.length,1);assert.equal(r.events.size,1);});
test('delayed event uses latest provider truth rather than payload',async()=>{const r=runtime(webhook,{payments:[{...payment,status:'REFUNDED'}]});await r.call();assert.equal(r.subscriptions[0].verified_payment_id,null);});
test('different product link cannot associate a subscription',async()=>{const r=runtime(webhook,{subscription:{paymentLink:'link_other'}});await r.call();assert.equal(r.subscriptions.length,0);});
test('API outage requests retry without entitlement',async()=>{const r=runtime(webhook,{apiFailure:true});assert.equal((await r.call()).status,503);assert.equal(r.subscriptions.length,0);});
test('cross-user association collision fails closed',async()=>{const r=runtime(webhook,{subscriptions:[{subscription_id:'sub_test',user_id:'user_b',customer_id:'cus_test'}]});assert.equal((await r.call()).status,503);assert.equal(r.subscriptions[0].user_id,'user_b');});
test('deleted subscription does not create paid access',async()=>{const r=runtime(webhook,{subscription:{deleted:true}});await r.call();assert.equal(r.subscriptions.length,0);});
test('unconfirmed email cannot start checkout',async()=>{const r=runtime(checkout,{user:{id:'user_a',email:'a@example.test'}});assert.equal((await r.call({}, {authorization:'Bearer '+token})).status,401);assert.equal(r.writes.length,0);});
test('lifetime Premium prevents checkout and retains previously granted access',async()=>{
 const r=runtime(checkout,{grants:[{grant_type:'lifetime',valid_until:null}],intents:[]});
 const response=await r.call({}, {authorization:'Bearer '+token});
 assert.equal(response.status,409);
 assert.equal((await response.json()).error,'lifetime_premium_no_checkout');
 assert.equal(r.writes.length,0);
 assert.equal(r.calls.filter(u=>u.includes('api-sandbox.asaas.com')).length,0);
});
test('browser identity cannot replace authenticated account',async()=>{const r=runtime(checkout,{intents:[]});assert.equal((await r.call({user_id:'user_b',email:'b@example.test'}, {authorization:'Bearer '+token})).status,200);assert.equal(r.writes[0].value.user_id,'user_a');assert.equal(r.writes[0].value.verified_email,'a@example.test');});
test('wrong price locks checkout',async()=>{const r=runtime(checkout,{link:{value:49.90}});assert.equal((await r.call({}, {authorization:'Bearer '+token})).status,503);assert.equal(r.writes.length,0);});
test('receipt from another product cannot extend paid period',async()=>{const r=runtime(webhook,{payments:[payment,{...payment,id:'pay_other',paymentLink:'link_other',dueDate:'2027-10-14'}]});await r.call();assert.equal(r.subscriptions[0].verified_payment_id,'pay_test');});
test('expired checkout intention cannot associate a new subscription',async()=>{const r=runtime(webhook,{intents:[{user_id:'user_a',expires_at:'2020-01-01T00:00:00Z'}]});await r.call();assert.equal(r.subscriptions.length,0);});
test('chargeback event reconciles current API status',async()=>{const r=runtime(webhook,{payments:[{...payment,status:'CHARGEBACK_REQUESTED'}]});await r.call({id:'evt_chargeback',event:'PAYMENT_CHARGEBACK_REQUESTED',payment:{subscription:'sub_test'}});assert.equal(r.subscriptions[0]?.paid_until,null);assert.equal(r.events.get('evt_chargeback')?.processing_state,'processed');});
test('existing owner can renew after checkout intention expires',async()=>{const r=runtime(webhook,{intents:[{user_id:'user_a',expires_at:'2020-01-01T00:00:00Z'}],subscriptions:[{subscription_id:'sub_test',user_id:'user_a',customer_id:'cus_test'}]});assert.equal((await r.call()).status,200);assert.equal(r.subscriptions[0].verified_payment_id,'pay_test');});
test('new checkout refreshes only authenticated owner intention',async()=>{const r=runtime(checkout);await r.call({}, {authorization:'Bearer '+token});assert.equal(r.writes[0].table,'folego_asaas_billing_intents');assert.ok(Date.parse(r.writes[0].value.expires_at)>Date.now());assert.ok(r.calls.some(u=>u.includes('user_id=eq.user_a')));});
test('month end validity uses calendar month and clamps February',async()=>{const r=runtime(webhook,{payments:[{...payment,dueDate:'2027-01-31'}]});await r.call();assert.equal(r.subscriptions[0].paid_until,'2027-02-28T00:00:00.000Z');});
