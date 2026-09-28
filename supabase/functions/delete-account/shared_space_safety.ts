// Defense-in-depth preflight for account deletion. The database BEFORE
// DELETE trigger is the authoritative backstop against races or alternate
// deletion paths. This helper converts the service-role lookup into a
// fail-closed decision before any potentially destructive operation.

export type OwnedSharedSpaceLookup = () => Promise<{
  data: unknown;
  error: unknown;
}>;

export type AccountDeletionPreflight =
  | "clear"
  | "shared_space_requires_resolution"
  | "shared_space_check_unavailable";

export async function accountDeletionPreflight(
  lookup: OwnedSharedSpaceLookup,
): Promise<AccountDeletionPreflight> {
  try {
    const result = await lookup();
    if (result.error != null || !Array.isArray(result.data)) {
      return "shared_space_check_unavailable";
    }
    return result.data.length > 0
      ? "shared_space_requires_resolution"
      : "clear";
  } catch (_) {
    return "shared_space_check_unavailable";
  }
}
