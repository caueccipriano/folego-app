// Fail-closed server-side Web Push subscription retrieval.
// Edge Functions must NEVER fall back to reading the unfiltered table.
// Only a service-role Postgres RPC may return endpoint secrets for sessions
// whose signed user/session identities are still present in auth.sessions.

export type VerifiedPushSubscription = {
  id: string;
  endpoint: string;
  p256dh: string;
  auth_secret: string;
};

export type VerifiedPushRpcClient = {
  rpc: (
    name: string,
    args: { p_user_id: string },
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

function isVerifiedPushRow(value: unknown): value is VerifiedPushSubscription {
  if (typeof value !== "object" || value === null) return false;
  const item = value as Record<string, unknown>;
  return (
    typeof item.id === "string" &&
    item.id.length > 0 &&
    typeof item.endpoint === "string" &&
    item.endpoint.startsWith("https://") &&
    typeof item.p256dh === "string" &&
    item.p256dh.length > 0 &&
    typeof item.auth_secret === "string" &&
    item.auth_secret.length > 0
  );
}

export async function loadVerifiedPushSubscriptions(
  admin: VerifiedPushRpcClient,
  userId: string,
): Promise<VerifiedPushSubscription[]> {
  const response = await admin.rpc("get_active_web_push_subscriptions", {
    p_user_id: userId,
  });
  if (response.error != null || !Array.isArray(response.data)) {
    throw new Error("verified_push_subscription_lookup_failed");
  }
  if (!response.data.every(isVerifiedPushRow)) {
    throw new Error("verified_push_subscription_response_malformed");
  }
  return response.data;
}

export async function isPushSubscriptionStillActive(
  admin: VerifiedPushRpcClient,
  userId: string,
  subscriptionId: string,
): Promise<boolean> {
  const current = await loadVerifiedPushSubscriptions(admin, userId);
  return current.some((entry) => entry.id === subscriptionId);
}
