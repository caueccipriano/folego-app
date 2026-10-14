/** Sandbox-only, authenticated Asaas webhook reconciliation for FÔLEGO.
 * This implementation cannot grant customer Premium (production-only reader).
 * Every notification is corroborated against the Asaas SANDBOX API.
 * No financial transaction, store_subscriptions, premium_grants or app data writes.
 */
const S=(key:string)=>Deno.env.get(key)||"";
const API="https://api-sandbox.asaas.com/v3";
const BASE=S("SUPABASE_URL");
const API_KEY=S("FOLEGO_ASAAS_SANDBOX_API_KEY");
const LINK_ID=S("FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_ID");
const LINK_URL=S("FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_URL");
const WEBHOOK_TOKEN=S("FOLEGO_ASAAS_SANDBOX_WEBHOOK_TOKEN");
const ENABLED=S("FOLEGO_ASAAS_SANDBOX_WEBHOOK_ENABLED")==="true";
function secretKey():string{
  try{const parsed=JSON.parse(S("SUPABASE_SECRET_KEYS"));return parsed.default||S("SUPABASE_SERVICE_ROLE_KEY");}
  catch{return S("SUPABASE_SERVICE_ROLE_KEY");}
}
const SECRET=secretKey();
const encoder=new TextEncoder();
const send=(body:object,status=200)=>Response.json(body,{status,headers:{"Cache-Control":"no-store"}});
function cents(v:unknown):number|null{
  if(typeof v!=="string"&&typeof v!=="number")return null;
  const s=String(v);
  if(!/^(0|[1-9]\d*)(\.\d{1,2})?$/.test(s))return null;
  const [whole,dec=""]=s.split(".");
  const value=Number(whole)*100+Number(dec.padEnd(2,"0"));
  return Number.isSafeInteger(value)?value:null;
}
async function safeEqual(a:string|null,b:string){
  if(!a||!b||a.length<32||b.length<32||a.length>255||b.length>255)return false;
  const [left,right]=await Promise.all([a,b].map(v=>crypto.subtle.digest("SHA-256",encoder.encode(v))));
  const l=new Uint8Array(left),r=new Uint8Array(right);
  let diff=0;for(let i=0;i<l.length;i++)diff|=l[i]^r[i];
  return diff===0;
}
async function asaas(path:string){
  const resp=await fetch(API+path,{headers:{"access_token":API_KEY,"accept":"application/json","User-Agent":"Folego-CIPRI/1.0"}});
  if(!resp.ok)throw new Error("asaas_unavailable");
  return resp.json();
}
async function db(path:string,init:RequestInit={}){
  const headers:Record<string,string>={"apikey":SECRET,"Content-Type":"application/json",...(init.headers as Record<string,string>||{})};
  if(SECRET.startsWith("eyJ"))headers.Authorization="Bearer "+SECRET;
  const response=await fetch(BASE+"/rest/v1/"+path,{...init,headers});
  if(!response.ok)throw new Error("database_unavailable");
  return response;
}
async function rows(path:string){return (await db(path)).json();}
async function upsert(table:string,conflict:string,payload:object){
  await db(table+"?on_conflict="+encodeURIComponent(conflict),{
    method:"POST",headers:{"Prefer":"resolution=merge-duplicates,return=minimal"},
    body:JSON.stringify(payload)
  });
}
function paidUntil(due:string):string|null{
  if(typeof due!=="string"||!/^\d{4}-\d\d-\d\d$/.test(due))return null;
  const [year,month,day]=due.split("-").map(Number);
  const original=new Date(Date.UTC(year,month-1,day));
  if(!Number.isFinite(original.getTime())||original.toISOString().slice(0,10)!==due)return null;
  const lastDay=new Date(Date.UTC(year,month+1,0)).getUTCDate();
  return new Date(Date.UTC(year,month,Math.min(day,lastDay))).toISOString();
}
async function verifyLink():Promise<void>{
  const link=await asaas("/paymentLinks/"+encodeURIComponent(LINK_ID));
  const expected=new URL(LINK_URL),actual=new URL(link.url);
  if(expected.protocol!=="https:"||!/^(?:[a-z0-9-]+\.)?asaas\.com$/i.test(expected.hostname)||
     actual.href!==expected.href||link.id!==LINK_ID||link.active===false||link.deleted===true||
     link.chargeType!=="RECURRENT"||link.subscriptionCycle!=="MONTHLY"||cents(link.value)!==990)
     throw new Error("wrong_checkout");
}
async function listPayments(subscriptionId:string){
  const payments:Record<string,unknown>[]=[];
  for(let offset=0;offset<500;offset+=100){
    const data=await asaas("/subscriptions/"+encodeURIComponent(subscriptionId)+"/payments?offset="+offset+"&limit=100");
    if(!Array.isArray(data.data))throw new Error("invalid_api_response");
    payments.push(...data.data);
    if(!data.hasMore)return payments;
  }
  throw new Error("payment_list_too_long");
}
function acceptablePayment(payment:any,sub:any){
  return payment&&typeof payment.id==="string"&&
     ["CONFIRMED","RECEIVED"].includes(payment.status)&&
     payment.subscription===sub.id&&payment.customer===sub.customer&&
     !payment.deleted&&!payment.refunded&&cents(payment.value)===990&&
     paidUntil(payment.dueDate)!==null;
}
const ACCEPTED=new Set(["PAYMENT_CREATED","PAYMENT_UPDATED","PAYMENT_CONFIRMED","PAYMENT_RECEIVED",
  "PAYMENT_OVERDUE","PAYMENT_REFUNDED","PAYMENT_DELETED","SUBSCRIPTION_CREATED",
  "SUBSCRIPTION_UPDATED","SUBSCRIPTION_INACTIVATED","SUBSCRIPTION_DELETED"]);
Deno.serve(async req=>{
 if(req.method!=="POST")return send({error:"method_not_allowed"},405);
 if(!ENABLED||!BASE||!SECRET||API_KEY.length<16||!LINK_ID||!LINK_URL||WEBHOOK_TOKEN.length<32)
   return send({error:"sandbox_not_configured"},503);
 if(!await safeEqual(req.headers.get("asaas-access-token"),WEBHOOK_TOKEN))
   return send({error:"unauthorized"},401);
 try{
   if(Number(req.headers.get("content-length")||"0")>16384)return send({error:"payload_too_large"},413);
   const raw=await req.text();
   if(encoder.encode(raw).length>16384)return send({error:"payload_too_large"},413);
   const event=JSON.parse(raw);
   if(!event||typeof event.id!=="string"||!/^[A-Za-z0-9_&.-]{4,180}$/.test(event.id)||
      typeof event.event!=="string")return send({error:"invalid_event"},400);
   if(!ACCEPTED.has(event.event))return send({ok:true,ignored:true});
   const id=event.payment?.subscription||event.subscription?.id;
   const eventRow={
     environment:"sandbox",event_id:event.id,event_type:event.event,
     subscription_id:typeof id==="string"?id:null,
     payment_id:typeof event.payment?.id==="string"?event.payment.id:null,
     processing_state:"pending"
   };
   await upsert("folego_asaas_events","environment,event_id",eventRow);
   const finish=async(state:string)=>{
     await upsert("folego_asaas_events","environment,event_id",{
       ...eventRow,processing_state:state,processed_at:new Date().toISOString()
     });
     return send({ok:true,state});
   };
   if(typeof id!=="string"||!/^[-_a-zA-Z0-9]{3,150}$/.test(id))
     return finish("ignored");
   await verifyLink();
   let sub:any;
   try{sub=await asaas("/subscriptions/"+encodeURIComponent(id));}
   catch{
     // Cannot infer receipt or entitlement from deletion notifications alone.
     // Retain pending state for investigated provider errors.
     throw new Error("subscription_lookup_failed");
   }
   if(!sub||sub.id!==id||!sub.customer||sub.cycle!=="MONTHLY"||cents(sub.value)!==990||
      sub.deleted===true||(sub.paymentLink&&sub.paymentLink!==LINK_ID))return finish("ignored");
   const customer=await asaas("/customers/"+encodeURIComponent(sub.customer));
   const email=typeof customer.email==="string"?customer.email.trim().toLowerCase():"";
   if(!email)return finish("unmatched");
   const intents=await rows("folego_asaas_billing_intents?environment=eq.sandbox&verified_email=eq."+encodeURIComponent(email)+"&plan=eq.monthly&select=user_id&limit=2");
   if(!Array.isArray(intents)||intents.length!==1)return finish("unmatched");
   const payments=await listPayments(id);
   const fromCorrectLink=sub.paymentLink===LINK_ID||payments.some(p=>
      p.paymentLink===LINK_ID&&p.subscription===id&&p.customer===sub.customer&&cents(p.value)===990);
   if(!fromCorrectLink)return finish("unmatched");
   const paid=payments.filter(p=>acceptablePayment(p,sub))
      .map(p=>({id:p.id,until:paidUntil(p.dueDate)})).sort((a,b)=>String(b.until).localeCompare(String(a.until)));
   const best=paid[0];
   const old=await rows("folego_asaas_subscriptions?environment=eq.sandbox&subscription_id=eq."+
      encodeURIComponent(id)+"&select=user_id,customer_id&limit=1");
   if(old.length&&(old[0].user_id!==intents[0].user_id||old[0].customer_id!==sub.customer))
      throw new Error("subscription_account_collision");
   await upsert("folego_asaas_subscriptions","environment,subscription_id",{
     environment:"sandbox",subscription_id:id,user_id:intents[0].user_id,
     customer_id:sub.customer,plan:"monthly",payment_link_id:LINK_ID,
     billing_status:sub.status||"UNKNOWN",verified_payment_id:best?.id||null,
     paid_until:best?.until||null,source_verified:true,updated_at:new Date().toISOString()
   });
   return finish("processed");
 }catch{
   // Force Asaas retry, do not acknowledge a reconciliation that failed.
   return send({error:"reconciliation_failed"},503);
 }
});
