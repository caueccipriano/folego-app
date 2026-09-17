import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

type Candidate = {
  user_id: string;
  space_id: string;
  stable_key: string;
  kind: string;
  title: string;
  body: string;
  route: string;
};

type PushSubscriptionRow = {
  id: string;
  endpoint: string;
  p256dh: string;
  auth_secret: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const token = typeof payload.cron_token === "string" ? payload.cron_token : "";
  if (!token) return json(401, { error: "missing_auth" });

  const { data: authorized, error: authError } = await supabase.rpc(
    "verify_web_push_cron_token",
    { p_token: token },
  );
  if (authError || authorized !== true) {
    return json(401, { error: "unauthorized" });
  }

  const { data: configRows, error: configError } = await supabase.rpc(
    "get_web_push_server_config",
  );
  if (configError || !Array.isArray(configRows) || configRows.length === 0) {
    console.error("web push config unavailable", configError?.code ?? "missing");
    return json(500, { error: "push_config_unavailable" });
  }

  const config = configRows[0] as {
    public_key: string;
    private_key: string;
    subject: string;
  };
  webpush.setVapidDetails(config.subject, config.public_key, config.private_key);

  const { data: candidatesData, error: candidatesError } = await supabase.rpc(
    "get_web_push_candidates",
    { p_now: new Date().toISOString(), p_limit: 100 },
  );
  if (candidatesError) {
    console.error("push candidate query failed", candidatesError.code);
    return json(500, { error: "candidate_query_failed" });
  }

  const candidates = (candidatesData ?? []) as Candidate[];
  let sent = 0;
  let disabled = 0;
  let failed = 0;

  for (const candidate of candidates) {
    const { data: subscriptionsData, error: subscriptionsError } = await supabase
      .from("web_push_subscriptions")
      .select("id,endpoint,p256dh,auth_secret")
      .eq("user_id", candidate.user_id)
      .is("disabled_at", null);

    if (subscriptionsError) {
      failed += 1;
      continue;
    }

    const subscriptions = (subscriptionsData ?? []) as PushSubscriptionRow[];
    let delivered = false;

    const pushPayload = JSON.stringify({
      title: candidate.title,
      body: candidate.body,
      route: candidate.route,
      tag: candidate.stable_key,
      icon: "icons/Icon-192.png",
      badge: "icons/Icon-192.png",
    });

    for (const subscription of subscriptions) {
      try {
        await webpush.sendNotification(
          {
            endpoint: subscription.endpoint,
            keys: {
              p256dh: subscription.p256dh,
              auth: subscription.auth_secret,
            },
          },
          pushPayload,
          {
            TTL: 60 * 60 * 12,
            urgency: candidate.kind === "overdue" ? "high" : "normal",
          },
        );

        delivered = true;
        sent += 1;
        await supabase
          .from("web_push_subscriptions")
          .update({
            last_success_at: new Date().toISOString(),
            failure_count: 0,
            updated_at: new Date().toISOString(),
          })
          .eq("id", subscription.id);
      } catch (error) {
        const statusCode =
          typeof error === "object" && error !== null && "statusCode" in error
            ? Number((error as { statusCode?: unknown }).statusCode)
            : 0;

        if (statusCode === 404 || statusCode === 410) {
          disabled += 1;
          await supabase
            .from("web_push_subscriptions")
            .update({
              disabled_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq("id", subscription.id);
        } else {
          failed += 1;
          await supabase
            .from("web_push_subscriptions")
            .update({ updated_at: new Date().toISOString() })
            .eq("id", subscription.id);
        }
      }
    }

    if (delivered) {
      const { error: markError } = await supabase.rpc("mark_web_push_delivered", {
        p_user_id: candidate.user_id,
        p_space_id: candidate.space_id,
        p_stable_key: candidate.stable_key,
        p_kind: candidate.kind,
      });
      if (markError) {
        console.error("push delivery dedupe mark failed", markError.code);
      }
    }
  }

  return json(200, {
    ok: true,
    candidates: candidates.length,
    sent,
    disabled,
    failed,
  });
});
