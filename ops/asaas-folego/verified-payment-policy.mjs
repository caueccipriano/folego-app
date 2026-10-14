/**
 * FÔLEGO × Asaas - policy core for an ISOLATED SANDBOX candidate.
 * NOT CONNECTED to the PWA, payments or Supabase entitlements.
 * Only server-retrieved Asaas API objects are admissible as inputs.
 * A webhook payload or browser redirect is NEVER proof of payment.
 */
export const PLANS=Object.freeze({
  monthly:Object.freeze({priceCents:990,cycle:"MONTHLY"}),
  yearly:Object.freeze({priceCents:8990,cycle:"YEARLY"})
});
export function asCents(value){
  if(typeof value!=="number" && typeof value!=="string") return null;
  const s=String(value);
  if(!/^(0|[1-9][0-9]*)(\.[0-9]{1,2})?$/.test(s)) return null;
  const [integer,decimal=""]=s.split(".");
  const cents=Number(integer)*100+Number(decimal.padEnd(2,"0"));
  return Number.isSafeInteger(cents)?cents:null;
}
export function linkMatchesPlan(link,planKey,expectedLinkId,expectedUrl){
  const plan=PLANS[planKey];
  if(!plan || !link || typeof link!=="object" ||
     typeof expectedLinkId!=="string" || !expectedLinkId ||
     typeof expectedUrl!=="string" || !expectedUrl) return false;
  let actual,expected;
  try{actual=new URL(link.url);expected=new URL(expectedUrl);}
  catch{return false;}
  if(actual.protocol!=="https:" || expected.protocol!=="https:" ||
     !/^(?:[a-z0-9-]+\.)?asaas\.com$/i.test(actual.hostname) ||
     actual.href!==expected.href) return false;
  return link.id===expectedLinkId &&
    link.active!==false && link.deleted!==true &&
    link.chargeType==="RECURRENT" &&
    link.subscriptionCycle===plan.cycle &&
    asCents(link.value)===plan.priceCents;
}
export function eligiblePaidInvoice({invoice,subscription,planKey,linkId}){
  const plan=PLANS[planKey];
  if(!plan || !invoice || !subscription || !linkId) return false;
  if(typeof subscription.id!=="string" || !subscription.id ||
     typeof subscription.customer!=="string" || !subscription.customer ||
     subscription.status!=="ACTIVE" || subscription.deleted===true ||
     subscription.cycle!==plan.cycle ||
     asCents(subscription.value)!==plan.priceCents) return false;
  if(invoice.subscription!==subscription.id ||
     invoice.customer!==subscription.customer ||
     !["CONFIRMED","RECEIVED"].includes(invoice.status) ||
     invoice.deleted===true || invoice.refunded===true ||
     asCents(invoice.value)!==plan.priceCents) return false;
  // Some Asaas subscriptions omit paymentLink. The original confirmed invoice
  // may prove link provenance instead; both values MUST come from Asaas API.
  return subscription.paymentLink===linkId || invoice.paymentLink===linkId;
}
export function evaluateVerifiedSubscription({
  planKey,link,expectedLinkId,expectedUrl,subscription,invoices
}){
  if(!linkMatchesPlan(link,planKey,expectedLinkId,expectedUrl))
    return Object.freeze({eligible:false,reason:"invalid_checkout_link"});
  if(!Array.isArray(invoices) || invoices.length===0)
    return Object.freeze({eligible:false,reason:"no_verified_payment"});
  const matching=invoices.find(invoice=>eligiblePaidInvoice({
    invoice,subscription,planKey,linkId:expectedLinkId
  }));
  if(!matching)
    return Object.freeze({eligible:false,reason:"no_verified_payment"});
  // Does not calculate valid_until, write to DB, or grant Premium.
  // Expiration, reversal, account ownership and idempotency belong to backend.
  return Object.freeze({eligible:true,verifiedPaymentId:matching.id||null});
}
