import { accountDeletionPreflight } from "./shared_space_safety.ts";

function equals<T>(actual: T, expected: T, context: string) {
  if (actual !== expected) {
    throw new Error(context + ": expected " + expected + ", received " + actual);
  }
}

Deno.test("an owner with only own memberships may delete", async () => {
  let lookups = 0;
  const result = await accountDeletionPreflight(async () => {
    lookups++;
    return { data: [], error: null };
  });
  equals(result, "clear", "sole owner preflight");
  equals(lookups, 1, "query count");
});

Deno.test("a shared owner is blocked before touching account data", async () => {
  const result = await accountDeletionPreflight(async () => ({
    data: [{ space_id: "synthetic-shared-space-id" }],
    error: null,
  }));
  equals(result, "shared_space_requires_resolution", "shared owner");
});

Deno.test("query errors fail closed rather than erasing shared data", async () => {
  const result = await accountDeletionPreflight(async () => ({
    data: [],
    error: { code: "POSTGREST_TEMPORARY_ERROR" },
  }));
  equals(result, "shared_space_check_unavailable", "query error");
});

Deno.test("missing/malformed lookup payloads fail closed", async () => {
  for (const data of [undefined, null, {}, ""]) {
    const result = await accountDeletionPreflight(async () => ({
      data,
      error: null,
    }));
    equals(result, "shared_space_check_unavailable", "malformed query");
  }
});

Deno.test("uncaught lookup exceptions fail closed", async () => {
  const result = await accountDeletionPreflight(() => {
    throw new Error("synthetic lookup exception");
  });
  equals(result, "shared_space_check_unavailable", "exception");
});
