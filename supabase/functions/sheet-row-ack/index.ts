import { createClient } from "npm:@supabase/supabase-js@2.116.0";

const HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HASH = /^[0-9a-f]{64}$/;
const json = (code: number, result: unknown) =>
  new Response(JSON.stringify(result), { status: code, headers: HEADERS });

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRole) {
    return json(503, { error: "server_unavailable" });
  }
  const spreadsheetId = req.headers.get("x-spreadsheet-id")?.trim() ?? "";
  const token = req.headers.get("x-folego-sync-token") ?? "";
  if (!spreadsheetId || !token) {
    return json(401, { error: "sync_credentials_required" });
  }
  const supabase = createClient(supabaseUrl, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Do not echo private sheet identifiers or tokens.
  const { data: integration, error: integrationError } = await supabase
    .from("sheet_sync_integrations")
    .select("id,space_id,token_hash")
    .eq("spreadsheet_id", spreadsheetId)
    .eq("enabled", true)
    .maybeSingle();
  if (integrationError) return json(503, { error: "integration_unavailable" });
  if (!integration || (await sha256(token)) !== integration.token_hash) {
    return json(401, { error: "invalid_sync_credentials" });
  }

  const content = await req.text();
  if (content.length > 120_000) return json(413, { error: "payload_too_large" });
  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(content);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw Error();
    body = parsed;
  } catch {
    return json(400, { error: "invalid_json" });
  }
  if (body.action !== "pull_ack" || !Array.isArray(body.rows) ||
      body.rows.length < 1 || body.rows.length > 100) {
    return json(400, { error: "invalid_action_or_batch" });
  }

  const results: Array<Record<string, unknown>> = [];
  for (const entry of body.rows) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      results.push({ status: "invalid_request" });
      continue;
    }
    const row = entry as Record<string, unknown>;
    const sheetRowId = typeof row.id === "string" ? row.id.trim() : "";
    const expectedVersion = typeof row.updated_at === "string" ? row.updated_at : "";
    const contentHash = typeof row.sha256 === "string" ? row.sha256 : "";
    if (!sheetRowId || sheetRowId.length > 160 ||
        !expectedVersion || expectedVersion.length > 64 ||
        !/^\d{4}-\d\d-\d\dT/.test(expectedVersion) ||
        !Number.isFinite(Date.parse(expectedVersion)) ||
        !HASH.test(contentHash)) {
      results.push({ id: sheetRowId.slice(0, 160), status: "invalid_request" });
      continue;
    }

    let eventId: string | undefined;
    if (sheetRowId.startsWith("event:")) {
      eventId = sheetRowId.slice(6);
      if (!UUID.test(eventId)) {
        results.push({ id: sheetRowId, status: "invalid_request" });
        continue;
      }
    } else {
      // The existing pull protocol returns the unprefixed sheet external ID.
      const externalId = sheetRowId.startsWith("sheet:") ? sheetRowId : `sheet:${sheetRowId}`;
      const { data: event, error } = await supabase
        .from("financial_events")
        .select("id")
        .eq("space_id", integration.space_id)
        .eq("external_id", externalId)
        .eq("status", "confirmed")
        .maybeSingle();
      if (error) {
        results.push({ id: sheetRowId, status: "query_failed" });
        continue;
      }
      eventId = event?.id;
      if (!eventId) {
        results.push({ id: sheetRowId, status: "event_not_found" });
        continue;
      }
    }

    const { data, error } = await supabase.rpc("record_folego_sheet_delivery_ack", {
      p_integration_id: integration.id,
      p_event_id: eventId,
      p_sheet_row_id: sheetRowId,
      p_expected_updated_at: expectedVersion,
      p_content_sha256: contentHash,
    });
    results.push({
      id: sheetRowId,
      ...(error ? { status: "server_error" } : data as Record<string, unknown>),
    });
  }
  // A batch HTTP 200 response is NOT a guarantee: each row has its own status.
  return json(200, { ok: true, results });
});
