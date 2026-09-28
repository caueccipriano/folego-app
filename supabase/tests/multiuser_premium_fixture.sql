-- Disposable two-user Premium fixture. No Supabase connection or secrets.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO authenticated;

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;

CREATE TABLE public.premium_grants(
  user_id uuid PRIMARY KEY,
  grant_type text NOT NULL CHECK (grant_type IN ('complimentary','lifetime')),
  valid_until timestamptz,
  note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.premium_grants ENABLE ROW LEVEL SECURITY;
CREATE POLICY premium_grants_select_own ON public.premium_grants
FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

-- Original Dev grants: no direct authenticated or anonymous SELECT.
REVOKE ALL ON public.premium_grants FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.get_my_premium_grant()
RETURNS TABLE(grant_type text, valid_until timestamptz)
LANGUAGE sql STABLE SET search_path TO ''
AS $$
  SELECT pg.grant_type,pg.valid_until
  FROM public.premium_grants pg
  WHERE pg.user_id=(SELECT auth.uid())
    AND (pg.valid_until IS NULL OR pg.valid_until > now())
  LIMIT 1
$$;
REVOKE ALL ON FUNCTION public.get_my_premium_grant() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_premium_grant() TO authenticated;

INSERT INTO public.premium_grants(user_id,grant_type,valid_until,note)
VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','complimentary',now()+interval '1 day','PRIVATE_ADMIN_NOTE'),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','lifetime',NULL,'PRIVATE_ADMIN_NOTE_2');
\echo 'PASS: two fictional Premium records and one Free user seeded.'
