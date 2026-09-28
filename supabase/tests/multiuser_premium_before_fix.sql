-- Prove existing production-shaped SECURITY INVOKER lookup fails for A.
\set ON_ERROR_STOP on
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false
);
DO $legacy$
DECLARE v_perm_denied boolean := false;
BEGIN
  BEGIN
    PERFORM * FROM public.get_my_premium_grant();
  EXCEPTION WHEN insufficient_privilege THEN
    v_perm_denied := true;
  END;
  IF NOT v_perm_denied THEN
    RAISE EXCEPTION 'legacy Premium grant permission regression not reproduced';
  END IF;
  RAISE NOTICE 'PASS: confirmed current invoker Premium grant lookup permission gap (synthetic user)';
END;
$legacy$;
RESET ROLE;
