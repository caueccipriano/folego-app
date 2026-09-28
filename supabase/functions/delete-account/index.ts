import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { accountDeletionPreflight } from "./shared_space_safety.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const authorization = req.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json(401, { error: "missing_auth" });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return json(401, { error: "invalid_session" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Preflight for a user who owns a financial space with other members.
  // !inner forces the ownership check on the joined financial_spaces table;
  // only *other* user_id values count. A failed lookup must block deletion.
  // The auth.users BEFORE DELETE trigger provides the authoritative,
  // same-transaction backstop, including concurrent or out-of-band requests.
  const ownerSafety = await accountDeletionPreflight(async () => {
    const { data, error } = await admin
      .from("space_members")
      .select("space_id,financial_spaces!inner(owner_id)")
      .eq("financial_spaces.owner_id", user.id)
      .neq("user_id", user.id)
      .limit(1);
    return { data, error };
  });

  if (ownerSafety === "shared_space_requires_resolution") {
    return json(409, { error: ownerSafety });
  }
  if (ownerSafety !== "clear") {
    return json(503, { error: "shared_space_check_unavailable" });
  }

  // The new database trigger deletes automation_rules authored by this
  // account in the SAME transaction as auth.users deletion. Do not perform
  // a separate service-role cleanup: if auth deletion later fails, that
  // would cause partial data loss in another user's shared financial space.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    if (
      deleteError.message?.includes(
        "shared_space_owner_deletion_requires_resolution",
      )
    ) {
      return json(409, { error: "shared_space_requires_resolution" });
    }
    console.error("delete-account auth deletion failed", deleteError.code);
    return json(500, { error: "delete_failed" });
  }

  return json(200, { deleted: true });
});
