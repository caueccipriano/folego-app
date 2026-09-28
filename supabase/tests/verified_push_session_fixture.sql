-- Ephemeral PostgreSQL 17 fixture, no linked Supabase accounts or endpoints.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT current_setting('request.jwt.claim.role',true)
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claims',true),''),
    '{}'
  )::jsonb
$$;

CREATE TABLE auth.sessions(
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL,
  not_after timestamptz
);
REVOKE ALL ON auth.sessions FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE public.web_push_subscriptions(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  endpoint text NOT NULL UNIQUE,
  p256dh text NOT NULL,
  auth_secret text NOT NULL,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_success_at timestamptz,
  failure_count integer NOT NULL DEFAULT 0,
  disabled_at timestamptz
);
ALTER TABLE public.web_push_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY web_push_subscriptions_select_own
ON public.web_push_subscriptions FOR SELECT TO authenticated
USING (auth.uid()=user_id);
CREATE POLICY web_push_subscriptions_insert_own
ON public.web_push_subscriptions FOR INSERT TO authenticated
WITH CHECK (auth.uid()=user_id);
CREATE POLICY web_push_subscriptions_update_own
ON public.web_push_subscriptions FOR UPDATE TO authenticated
USING (auth.uid()=user_id) WITH CHECK(auth.uid()=user_id);
CREATE POLICY web_push_subscriptions_delete_own
ON public.web_push_subscriptions FOR DELETE TO authenticated
USING (auth.uid()=user_id);
REVOKE ALL ON TABLE public.web_push_subscriptions FROM PUBLIC,anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.web_push_subscriptions
TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.web_push_subscriptions
TO service_role;

-- Two independent fictional users and two independent A devices.
INSERT INTO auth.sessions(id,user_id,not_after) VALUES
('a0000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',NULL),
('a0000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',NULL),
('a0000000-0000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',now()-interval '1 hour'),
('b0000000-0000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',NULL);

-- Current production-shaped legacy endpoint has no session binding.
INSERT INTO public.web_push_subscriptions(
  user_id,endpoint,p256dh,auth_secret
) VALUES(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'https://push.synthetic.invalid/a-legacy',
  'synthetic-p256dh',
  'synthetic-secret'
);

\echo 'PASS: synthetic signed-claim stand-ins, independent sessions and legacy endpoint seeded.'
