import {
  isPushSubscriptionStillActive,
  loadVerifiedPushSubscriptions,
  type VerifiedPushRpcClient,
} from "./verified_push_subscriptions.ts";

function assertEqual<T>(actual: T, expected: T, context: string) {
  if (actual !== expected) {
    throw new Error(context + ": expected " + expected + ", got " + actual);
  }
}

function fake(
  handler: (
    name: string,
    args: { p_user_id: string },
  ) => Promise<{ data: unknown; error: unknown }>,
): VerifiedPushRpcClient {
  return { rpc: handler };
}

const validA1 = {
  id: "synthetic-device-a1",
  endpoint: "https://push.synthetic.invalid/a1",
  p256dh: "synthetic-public-key",
  auth_secret: "synthetic-key",
};

Deno.test("service lookup accepts only verified RPC rows", async () => {
  let calls = 0;
  const admin = fake(async (name, args) => {
    calls++;
    assertEqual(name, "get_active_web_push_subscriptions", "RPC name");
    assertEqual(args.p_user_id, "synthetic-a", "user filter");
    return { data: [validA1], error: null };
  });
  const rows = await loadVerifiedPushSubscriptions(admin, "synthetic-a");
  assertEqual(rows.length, 1, "verified device count");
  assertEqual(calls, 1, "query count");
});

Deno.test("missing migration or lookup failure never falls back to raw table", async () => {
  let calls = 0;
  const admin = fake(async () => {
    calls++;
    return {
      data: null,
      error: { code: "PGRST202", message: "RPC unavailable" },
    };
  });

  let threw = false;
  try {
    await loadVerifiedPushSubscriptions(admin, "synthetic-a");
  } catch (error) {
    threw = String(error).includes("verified_push_subscription_lookup_failed");
  }
  assertEqual(threw, true, "fail closed on missing session verification");
  assertEqual(calls, 1, "only one RPC; no fallback");
});

Deno.test("malformed row with no session-verified keys fails closed", async () => {
  const admin = fake(async () => ({
    data: [{ id: "bad", endpoint: "https://push.invalid" }],
    error: null,
  }));
  let threw = false;
  try {
    await loadVerifiedPushSubscriptions(admin, "synthetic-a");
  } catch (error) {
    threw = String(error).includes("verified_push_subscription_response_malformed");
  }
  assertEqual(threw, true, "no partially unverified send");
});

Deno.test("non-array and thrown service errors fail closed", async () => {
  for (const response of [{ data: {}, error: null }, { data: null, error: null }]) {
    let threw = false;
    try {
      await loadVerifiedPushSubscriptions(fake(async () => response), "synthetic-a");
    } catch (_) {
      threw = true;
    }
    assertEqual(threw, true, "invalid service result");
  }

  let threw = false;
  try {
    await loadVerifiedPushSubscriptions(
      fake(async () => { throw Error("synthetic DB unavailable"); }),
      "synthetic-a",
    );
  } catch (_) {
    threw = true;
  }
  assertEqual(threw, true, "RPC/network errors must block delivery");
});

Deno.test("session revoked between selection and send suppresses notification", async () => {
  let calls = 0;
  const admin = fake(async () => {
    calls++;
    return { data: calls === 1 ? [validA1] : [], error: null };
  });
  const before = await loadVerifiedPushSubscriptions(admin, "synthetic-a");
  assertEqual(before.length, 1, "initial session");
  const sendEligible = await isPushSubscriptionStillActive(
    admin, "synthetic-a", before[0].id,
  );
  assertEqual(sendEligible, false, "revoked immediately before send");
  assertEqual(calls, 2, "independent verification before delivery");
});

Deno.test("active independent device remains eligible", async () => {
  const admin = fake(async () => ({
    data: [validA1],
    error: null,
  }));
  assertEqual(
    await isPushSubscriptionStillActive(admin, "synthetic-a", validA1.id),
    true,
    "valid device",
  );
  assertEqual(
    await isPushSubscriptionStillActive(admin, "synthetic-a", "different-id"),
    false,
    "unknown device",
  );
});
