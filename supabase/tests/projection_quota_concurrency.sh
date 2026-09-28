#!/usr/bin/env bash
# Executes on disposable CI Postgres only. PGHOST/PGUSER/PGDATABASE and
# PGPASSWORD are supplied by the isolated GitHub Actions job.
set -euo pipefail

logdir="$(mktemp -d)"
trap 'rm -rf "$logdir"' EXIT

run_scenario() {
  local label="$1"
  psql -X -v ON_ERROR_STOP=1 -qAt \
    -c 'SET ROLE authenticated' \
    -c "SELECT set_config('request.jwt.claim.sub','dddddddd-dddd-4ddd-8ddd-dddddddddddd',false)" \
    -c "SELECT public.get_projection(
          '44444444-4444-4444-8444-444444444444',
          12, '[{\"id\":\"concurrent-test\"}]'::jsonb,
          '{}'::text[]
        )" >"$logdir/$label.log" 2>&1
}

run_scenario one &
pid_one=$!
run_scenario two &
pid_two=$!

result_one=1
result_two=1
wait "$pid_one" && result_one=0 || true
wait "$pid_two" && result_two=0 || true

successes=$(( (result_one==0) + (result_two==0) ))
if [[ "$successes" -ne 1 ]]; then
  echo "FAIL: concurrent last-attempt requests had $successes successes; expected exactly 1"
  cat "$logdir/one.log" "$logdir/two.log"
  exit 1
fi

denial_file="$logdir/one.log"
if [[ "$result_one" -eq 0 ]]; then
  denial_file="$logdir/two.log"
fi
if ! grep -q 'free_simulation_limit_reached' "$denial_file"; then
  echo "FAIL: rejected request did not receive the correct quota error"
  cat "$logdir/one.log" "$logdir/two.log"
  exit 1
fi

actual="$(psql -X -v ON_ERROR_STOP=1 -qAt \
  -c "SELECT used FROM public.financial_intelligence_usage
      WHERE user_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'
        AND capability='simulation'")"
if [[ "$actual" != 3 ]]; then
  echo "FAIL: concurrent quota was $actual instead of 3"
  exit 1
fi

echo "PASS: concurrent last free attempt: one success, one denial, usage=3"
