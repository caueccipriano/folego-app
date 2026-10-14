/** FÔLEGO PWA / Asaas sandbox checkout intent; always sandbox, never charges real money.
 * Does not modify the finance ledger or premium subscriptions.
 * Deployment needs a separate, reviewed step after DB migration and secrets.
 */
const env=(key:string)=>Deno.env.get(key)||"";
const SUPABASE_URL=env("SUPABASE_URL");
function managedKey(jsonName:string,legacyName:string):string{
  try{const obj=JSON.parse(env(jsonName));return obj.default||env(legacyName);}
  catch{return env(legacyName);}
}
const PUBLISHABLE=managedKey("SUPABASE_PUBLISHABLE_KEYS","SUPABASE_ANON_KEY");
const SECRET=managedKey("SUPABASE_SECRET_KEYS","SUPABASE_SERVICE_ROLE_KEY");
const ORIGIN=env("FOLEGO_ASAAS_ALLOWED_ORIGIN")||"https://caueccipriano.github.io";
const API="https://api-sandbox.asaas.com/v3";
const accessToken=env("FOLEGO_ASAAS_SANDBOX_API_KEY");
const linkId=env("FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_ID");
const linkUrl=env("FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_URL");
const allowCheckout=env("FOLEGO_ASAAS_SANDBOX_CHECKOUT_ENABLED")==="true";
const headers={"Cache-Control":"no-store","Access-Control-Allow-Origin":ORIGIN,"Vary":"Origin"};
function reply(obj:object,status=200){return Response.json(obj,{status,headers});}
function cents(v:unknown):number|null {
  if(typeof v!=="string"&&typeof v!=="number")return null;
  const s=String(v);
  if(!/^(0|[1-9]\d*)(\.\d{1,2})?$/.test(s))return null;
  const [w,c=""]=s.split(".");
  const n=Number(w)*100+Number(c.padEnd(2,"0"));
  return Number.isSafeInteger(n)?n:null;
}
async function fetchLink():Promise<boolean>{
  if(!allowCheckout||accessToken.length<16||!linkId||!linkUrl)return false;
  const r=await fetch(API+"/paymentLinks/"+encodeURIComponent(linkId),{
    headers:{"access_token":accessToken,"accept":"application/json","User-Agent":"Folego-CIPRI/1.0"}
  });
  if(!r.ok)return false;
  const o=await r.json();
  let expected:URL,actual:URL;
  try{expected=new URL(linkUrl);actual=new URL(o.url);}catch{return false;}
  return expected.protocol==="https:" &&
     /^(?:[a-z0-9-]+\.)?asaas\.com$/i.test(expected.hostname) &&
     actual.href===expected.href && o.id===linkId &&
     o.active!==false && o.deleted!==true &&
     o.chargeType==="RECURRENT" && o.subscriptionCycle==="MONTHLY" && cents(o.value)===990;
}
async function authUser(req:Request):Promise<{id:string,email:string}|null>{
  const bearer=req.headers.get("authorization")||"";
  if(!/^Bearer [A-Za-z0-9._-]{20,}$/.test(bearer))return null;
  const r=await fetch(SUPABASE_URL+"/auth/v1/user",{
    headers:{"apikey":PUBLISHABLE,"authorization":bearer}
  });
  if(!r.ok)return null;
  const user=await r.json();
  if(!user?.id||!user?.email_confirmed_at||typeof user?.email!=="string")return null;
  return {id:user.id,email:user.email.trim().toLowerCase()};
}
async function db(path:string,init:RequestInit={}):Promise<Response>{
  const h:Record<string,string>={"apikey":SECRET,"Content-Type":"application/json",...(init.headers as Record<string,string>||{})};
  if(SECRET.startsWith("eyJ"))h["Authorization"]="Bearer "+SECRET;
  return fetch(SUPABASE_URL+"/rest/v1/"+path,{...init,headers:h});
}
Deno.serve(async req=>{
  if(req.headers.get("origin")&&req.headers.get("origin")!==ORIGIN)return reply({error:"origin_denied"},403);
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:{...headers,"Access-Control-Allow-Methods":"GET,POST,OPTIONS","Access-Control-Allow-Headers":"Authorization,apikey,Content-Type"}});
  if(req.method!=="GET"&&req.method!=="POST")return reply({error:"method_not_allowed"},405);
  if(!SUPABASE_URL||!PUBLISHABLE||!SECRET)return reply({error:"backend_unconfigured"},503);
  try{
    const user=await authUser(req);
    if(!user)return reply({error:"verified_login_required"},401);
    const ready=await fetchLink();
    if(req.method==="GET")return reply({ready,environment:"sandbox",plan:"monthly",amount:9.90});
    if(!ready)return reply({error:"sandbox_checkout_locked"},503);
    // The user ID and e-mail come ONLY from Supabase Auth; not from the caller.
    const lookup=await db("folego_asaas_billing_intents?environment=eq.sandbox&verified_email=eq."+encodeURIComponent(user.email)+"&select=user_id,plan&limit=1");
    if(!lookup.ok)return reply({error:"intent_lookup_failed"},503);
    const existing=await lookup.json();
    if(existing.length && existing[0].user_id!==user.id)return reply({error:"email_account_conflict"},409);
    if(existing.length && existing[0].plan!=="monthly")return reply({error:"plan_account_conflict"},409);
    if(!existing.length){
      const inserted=await db("folego_asaas_billing_intents",{
        method:"POST",headers:{"Prefer":"return=minimal"},
        body:JSON.stringify({user_id:user.id,environment:"sandbox",verified_email:user.email,plan:"monthly"})
      });
      if(!inserted.ok)return reply({error:"intent_save_failed"},503);
    }
    return reply({ready:true,checkoutUrl:linkUrl,environment:"sandbox",plan:"monthly"});
  }catch{return reply({error:"temporarily_unavailable"},503);}
});
