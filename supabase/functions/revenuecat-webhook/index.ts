// RevenueCat webhook: configure REVENUECAT_WEBHOOK_SECRET in Supabase secrets
// and the identical Authorization bearer value in RevenueCat BEFORE deployment.
// No client-provided premium status is trusted.
import { createClient } from 'npm:@supabase/supabase-js@2';
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{'content-type':'application/json'}});
Deno.serve(async(req)=>{
 if(req.method!=='POST') return reply(405,'Method not allowed');
 const secret=Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
 if(!secret || req.headers.get('authorization')!==`Bearer ${secret}`) return reply(401,'Unauthorized');
 const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 const url=Deno.env.get('SUPABASE_URL');
 if(!serviceKey||!url) return reply(503,'Server not configured');
 let payload:unknown;
 try {payload=await req.json();} catch {return reply(400,'Invalid JSON');}
 if(!payload||typeof payload!=='object'||!('event' in payload)) return reply(400,'Missing event');
 const e=(payload as {event:Record<string,unknown>}).event;
 if(!e||typeof e!=='object'||typeof e.id!=='string'||typeof e.type!=='string') return reply(400,'Invalid event');
 const eventId=e.id, type=e.type;
 const appUserId=e.app_user_id;
 const entitlementIds=e.entitlement_ids;
 if(typeof appUserId!=='string'|| !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(appUserId)) return reply(200,'Ignored: non-UUID identity');
 if(!Array.isArray(entitlementIds)||!entitlementIds.includes('premium')) return reply(200,'Ignored: unrelated entitlement');
 // An atomic database handler provides event deduplication and event-time ordering.
 const db=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {error}=await db.rpc('apply_verified_subscription_event',{
   p_event_id:eventId,p_event_type:type,p_user_id:appUserId,
   p_expires_at_ms:typeof e.expiration_at_ms==='number'?e.expiration_at_ms:null,
   p_event_at_ms:typeof e.event_timestamp_ms==='number'?e.event_timestamp_ms:null
 });
 if(error) {console.error('Subscription event rejected',error.code);return reply(500,'Event not processed');}
 return reply(200,'OK');
});
