import test from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
const sql=readFileSync(new URL("./folego_asaas_candidate.sql",import.meta.url),"utf8");
const checkout=readFileSync(new URL("../../supabase/functions/folego-asaas-checkout-sandbox/index.ts",import.meta.url),"utf8");
const webhook=readFileSync(new URL("../../supabase/functions/folego-asaas-webhook-sandbox/index.ts",import.meta.url),"utf8");
test("billing database is independent from financial ledger and other products",()=>{
 for(const name of ["folego_asaas_billing_intents","folego_asaas_events","folego_asaas_subscriptions"])
  assert.match(sql,new RegExp("create table if not exists public\\."+name));
 for(const forbidden of ["update public.events","update public.accounts","edit alume","editalume_entitlements","insert into public.store_subscriptions","insert into public.premium_grants"])
  assert.doesNotMatch(sql,new RegExp(forbidden,"i"));
});
test("billing tables do not grant customers INSERT or UPDATE",()=>{
 assert.match(sql,/enable row level security/g);
 for(const name of ["folego_asaas_billing_intents","folego_asaas_events","folego_asaas_subscriptions"])
   assert.ok(sql.includes("revoke all on public."+name+" from public,anon,authenticated"));
 assert.doesNotMatch(sql,/grant (insert|update|delete) on/gi);
});
test("public reader cannot make sandbox entitlements premium",()=>{
 assert.match(sql,/s\.environment='production'/);
 assert.match(sql,/s\.source_verified=true/);
 assert.match(sql,/s\.paid_until>now\(\)/);
 assert.match(sql,/s\.user_id=\(select auth\.uid\(\)\)/);
});
test("sandbox functions do not enable real charging or client-granted benefits",()=>{
 for(const source of [checkout,webhook]){
   assert.match(source,/api-sandbox\.asaas\.com/);
   assert.doesNotMatch(source,/https:\/\/api\.asaas\.com\/v3/);
   assert.doesNotMatch(source,/store_subscriptions\?on_conflict/);
   assert.doesNotMatch(source,/premium_grants\?on_conflict/);
 }
 assert.match(checkout,/email_confirmed_at/);
 assert.match(checkout,/auth\/v1\/user/);
 assert.match(webhook,/asaas-access-token/);
 assert.match(webhook,/folego_asaas_events/);
 assert.match(webhook,/folego_asaas_subscriptions/);
});

test("pioneer lifetime Premium is server-side protected from checkout",()=>{
 assert.match(checkout,/premium_grants\?user_id=eq\./);
 assert.match(checkout,/g\.grant_type==="lifetime"&&g\.valid_until==null/);
 assert.match(checkout,/error:"lifetime_premium_no_checkout"/);
 assert.match(checkout,/amount:0,paymentConfirmed:false,premium:true/);
 assert.doesNotMatch(checkout,/api\.asaas\.com\/v3/);
});
