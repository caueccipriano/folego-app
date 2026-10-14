import test from "node:test";
import assert from "node:assert/strict";
import {PLANS,asCents,linkMatchesPlan,eligiblePaidInvoice,evaluateVerifiedSubscription} from "./verified-payment-policy.mjs";

const URL="https://www.asaas.com/000/c/sandbox-example";
const ID="link_sandbox_example";
function fixture(planKey="monthly"){
 const plan=PLANS[planKey];
 return {
   planKey,
   expectedLinkId:ID,
   expectedUrl:URL,
   link:{id:ID,active:true,url:URL,chargeType:"RECURRENT",subscriptionCycle:plan.cycle,value:plan.priceCents/100},
   subscription:{id:"sub_alpha",status:"ACTIVE",customer:"cus_alpha",cycle:plan.cycle,value:plan.priceCents/100,paymentLink:ID},
   invoices:[{id:"pay_alpha",status:"CONFIRMED",subscription:"sub_alpha",customer:"cus_alpha",value:plan.priceCents/100,paymentLink:ID}]
 };
}
const allowed=f=>evaluateVerifiedSubscription(f).eligible;

test("monthly and yearly prices remain locked",()=>{
 assert.deepEqual(PLANS.monthly,{priceCents:990,cycle:"MONTHLY"});
 assert.deepEqual(PLANS.yearly,{priceCents:8990,cycle:"YEARLY"});
 assert.equal(asCents("9.90"),990);
 assert.equal(asCents(89.9),8990);
 assert.equal(asCents("9.999"),null);
 assert.equal(asCents("-9.90"),null);
});
test("both plans accept matching Asaas API response only",()=>{
 assert.equal(allowed(fixture()),true);
 assert.equal(allowed(fixture("yearly")),true);
});
test("wrong cycle or amount rejects checkout",()=>{
 const x=fixture();x.link.value=10;
 assert.equal(allowed(x),false);
 x.link.value=9.90;x.link.subscriptionCycle="YEARLY";
 assert.equal(allowed(x),false);
});
test("unknown or off-domain checkout rejects",()=>{
 const x=fixture();x.link.url="https://fake-asaas.example/pay";
 assert.equal(allowed(x),false);
 x.link.url=URL;x.expectedLinkId="another_link";
 assert.equal(allowed(x),false);
});
test("unpaid, reversed and deleted invoices are denied",()=>{
 for (const status of ["PENDING","OVERDUE","REFUNDED","REFUND_REQUESTED","CHARGEBACK_REQUESTED"]) {
   const x=fixture();x.invoices[0].status=status;
   assert.equal(allowed(x),false,status);
 }
 const x=fixture();x.invoices[0].deleted=true;assert.equal(allowed(x),false);
});
test("subscription created without a paid invoice is denied",()=>{
 const x=fixture();x.invoices=[];
 assert.deepEqual(evaluateVerifiedSubscription(x),{eligible:false,reason:"no_verified_payment"});
});
test("cross-account or cross-subscription invoice is denied",()=>{
 const x=fixture();x.invoices[0].customer="cus_other";
 assert.equal(allowed(x),false);
 x.invoices[0].customer="cus_alpha";x.invoices[0].subscription="sub_other";
 assert.equal(allowed(x),false);
});
test("subscription requires active state, cycle and exact amount",()=>{
 const x=fixture();x.subscription.status="INACTIVE";assert.equal(allowed(x),false);
 x.subscription.status="ACTIVE";x.subscription.value=19.90;assert.equal(allowed(x),false);
});
test("provenance may be established by invoice if subscription omits link",()=>{
 const x=fixture();delete x.subscription.paymentLink;
 assert.equal(allowed(x),true);
 delete x.invoices[0].paymentLink;
 assert.equal(allowed(x),false);
});
test("one valid paid invoice is necessary; browser event is not used",()=>{
 const x=fixture();x.invoices=[{id:"pay_fake",status:"PENDING",subscription:"sub_alpha",customer:"cus_alpha",value:9.9},x.invoices[0]];
 assert.equal(allowed(x),true);
 const y=fixture();y.invoices=[{id:"pay_fake",status:"PENDING",subscription:"sub_alpha",customer:"cus_alpha",value:9.9}];
 assert.equal(allowed(y),false);
});
test("wrong billing environment, free accounts and duplicates do not grant rights",()=>{
 const x=fixture();x.link.active=false;assert.equal(allowed(x),false);
 assert.equal(linkMatchesPlan(x.link,x.planKey,ID,URL),false);
 assert.equal(eligiblePaidInvoice({invoice:null,subscription:x.subscription,planKey:x.planKey,linkId:ID}),false);
 // This pure module contains no Supabase writes: verification is not entitlement.
});
