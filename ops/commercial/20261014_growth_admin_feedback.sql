-- FÔLEGO: source-controlled reference for the growth/admin/feedback migration
-- Applied to project ycumrvkwqizlnehelhek on 2026-10-14.
-- Provision administrators separately, never via public user metadata or e-mail input.
-- This script does not create payments, touch financial balances, or grant premium.

CREATE TABLE IF NOT EXISTS private.folego_admins (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON private.folego_admins FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.folego_product_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('idea', 'bug', 'praise')),
  message text NOT NULL CHECK (char_length(btrim(message)) BETWEEN 8 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS folego_product_feedback_by_owner
  ON public.folego_product_feedback (user_id, created_at DESC);
ALTER TABLE public.folego_product_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.folego_product_feedback FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.folego_product_feedback TO authenticated;
DROP POLICY IF EXISTS folego_feedback_select_own ON public.folego_product_feedback;
CREATE POLICY folego_feedback_select_own ON public.folego_product_feedback
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS folego_feedback_insert_own ON public.folego_product_feedback;
CREATE POLICY folego_feedback_insert_own ON public.folego_product_feedback
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE OR REPLACE FUNCTION public.folego_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT (SELECT auth.uid()) IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM private.folego_admins a
      WHERE a.user_id = (SELECT auth.uid())
    );
$$;
REVOKE ALL ON FUNCTION public.folego_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.folego_is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.folego_admin_dashboard()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_users jsonb;
  v_feedback jsonb;
  v_metrics jsonb;
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT EXISTS (
    SELECT 1 FROM private.folego_admins a WHERE a.user_id = (SELECT auth.uid())
  ) THEN
    RAISE EXCEPTION 'folego_admin_only' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'name',coalesce(p.full_name,''),
      'email',u.email,
      'created_at',u.created_at,
      'last_login',u.last_sign_in_at,
      'email_confirmed',u.email_confirmed_at IS NOT NULL,
      'lifetime_premium',g.grant_type = 'lifetime' AND g.valid_until IS NULL
    ) ORDER BY u.created_at DESC
  ),'[]'::jsonb)
  INTO v_users
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  LEFT JOIN public.premium_grants g ON g.user_id = u.id;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'kind',f.kind,'message',f.message,'created_at',f.created_at,
      'name',coalesce(p.full_name,''),'email',u.email
    ) ORDER BY f.created_at DESC
  ),'[]'::jsonb)
  INTO v_feedback
  FROM (
    SELECT user_id,kind,message,created_at
    FROM public.folego_product_feedback
    ORDER BY created_at DESC LIMIT 50
  ) f
  LEFT JOIN auth.users u ON u.id = f.user_id
  LEFT JOIN public.profiles p ON p.id = f.user_id;

  SELECT jsonb_build_object(
    'registered',(SELECT count(*) FROM auth.users),
    'confirmed',(SELECT count(*) FROM auth.users WHERE email_confirmed_at IS NOT NULL),
    'logged_in_30d',(SELECT count(*) FROM auth.users WHERE last_sign_in_at >= now() - interval '30 days'),
    'lifetime_premium',(SELECT count(*) FROM public.premium_grants WHERE grant_type='lifetime' AND valid_until IS NULL),
    'sandbox_subscription_records',(SELECT count(*) FROM public.folego_asaas_subscriptions WHERE environment='sandbox'),
    'production_subscription_records',(SELECT count(*) FROM public.folego_asaas_subscriptions WHERE environment='production'),
    'feedback_count',(SELECT count(*) FROM public.folego_product_feedback),
    'completed_intro',(SELECT count(*) FROM public.profiles WHERE onboarding_completed),
    'users_with_account',(SELECT count(DISTINCT fs.owner_id) FROM public.accounts a JOIN public.financial_spaces fs ON fs.id = a.space_id),
    'users_with_transactions',(SELECT count(DISTINCT fs.owner_id) FROM public.financial_events e JOIN public.financial_spaces fs ON fs.id = e.space_id),
    'users_with_transactions_30d',(SELECT count(DISTINCT fs.owner_id) FROM public.financial_events e JOIN public.financial_spaces fs ON fs.id = e.space_id WHERE e.created_at >= now() - interval '30 days')
  ) INTO v_metrics;

  RETURN jsonb_build_object('metrics',v_metrics,'users',v_users,'feedback',v_feedback);
END
$$;
REVOKE ALL ON FUNCTION public.folego_admin_dashboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.folego_admin_dashboard() TO authenticated;

-- Manual privileged admin provisioning is intentionally omitted.
-- Validation: authenticated non-admin receives folego_admin_only.
-- No anonymous EXECUTE, no client SELECT on private.folego_admins.
