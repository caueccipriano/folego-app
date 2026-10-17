-- V3.5.3 additive notification/staging schema. No financial backfill or accounting RPC changes.
ALTER TABLE public.sheet_sync_integrations ADD COLUMN IF NOT EXISTS capture_counterparty_aliases jsonb NOT NULL DEFAULT '{}'::jsonb;
-- Integration-specific counterparty aliases are configured privately, outside this migration.
ALTER TABLE public.notification_history ADD COLUMN IF NOT EXISTS payload jsonb NOT NULL DEFAULT '{}'::jsonb;
-- Keep the existing own-user policy; add a restrictive membership guard for payload isolation.
CREATE POLICY notification_history_space_member_v353 ON public.notification_history AS RESTRICTIVE FOR SELECT TO authenticated USING((SELECT private.is_space_member(space_id)));
ALTER TABLE public.notification_preferences ADD COLUMN IF NOT EXISTS transaction_activity_enabled boolean NOT NULL DEFAULT true;
CREATE TABLE IF NOT EXISTS public.financial_capture_inbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), space_id uuid NOT NULL REFERENCES public.financial_spaces(id) ON DELETE CASCADE,
 provider text NOT NULL DEFAULT 'MercadoPago', source_kind text NOT NULL CHECK(source_kind IN ('gmail','notification','statement')),
 source_hash text NOT NULL, provider_transaction_id text, direction text NOT NULL CHECK(direction IN ('in','out','unknown')), amount numeric(16,2) NOT NULL CHECK(amount>0),
 counterparty text, description text NOT NULL, occurred_at timestamptz NOT NULL,
 review_status text NOT NULL DEFAULT 'needs_review' CHECK(review_status IN ('needs_review','linked','ignored')),
 linked_event_id uuid REFERENCES public.financial_events(id) ON DELETE SET NULL,
 review_reason text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(),reviewed_at timestamptz,
 UNIQUE(space_id,provider,source_kind,source_hash)
);
ALTER TABLE public.financial_capture_inbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financial_capture_inbox FROM anon,authenticated;
GRANT SELECT ON public.financial_capture_inbox TO authenticated;
GRANT ALL ON public.financial_capture_inbox TO service_role;
CREATE POLICY financial_capture_inbox_select_own ON public.financial_capture_inbox FOR SELECT TO authenticated USING((SELECT private.is_space_member(space_id)));
CREATE UNIQUE INDEX financial_capture_provider_id_unique ON public.financial_capture_inbox(space_id,provider,provider_transaction_id) WHERE provider_transaction_id IS NOT NULL;
CREATE INDEX financial_capture_inbox_space_review_idx ON public.financial_capture_inbox(space_id,review_status,created_at DESC);
CREATE TABLE public.financial_activity_read_state (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,space_id uuid NOT NULL REFERENCES public.financial_spaces(id) ON DELETE CASCADE,
 stable_key text NOT NULL,seen_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,stable_key)
);
ALTER TABLE public.financial_activity_read_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financial_activity_read_state FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.financial_activity_read_state TO authenticated;
GRANT ALL ON public.financial_activity_read_state TO service_role;
CREATE POLICY financial_activity_read_own ON public.financial_activity_read_state FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()) AND (SELECT private.is_space_member(space_id)));
CREATE POLICY financial_activity_ack_own ON public.financial_activity_read_state FOR INSERT TO authenticated WITH CHECK(user_id=(SELECT auth.uid()) AND (SELECT private.is_space_member(space_id)) AND EXISTS(SELECT 1 FROM public.notification_history n WHERE n.user_id=(SELECT auth.uid()) AND n.space_id=financial_activity_read_state.space_id AND coalesce(nullif(n.stable_key,''),'legacy:'||n.id::text)=financial_activity_read_state.stable_key));
CREATE POLICY financial_activity_ack_update_own ON public.financial_activity_read_state FOR UPDATE TO authenticated USING(user_id=(SELECT auth.uid()) AND (SELECT private.is_space_member(space_id))) WITH CHECK(user_id=(SELECT auth.uid()) AND (SELECT private.is_space_member(space_id)) AND EXISTS(SELECT 1 FROM public.notification_history n WHERE n.user_id=(SELECT auth.uid()) AND n.space_id=financial_activity_read_state.space_id AND coalesce(nullif(n.stable_key,''),'legacy:'||n.id::text)=financial_activity_read_state.stable_key));
CREATE FUNCTION private.folego_capture_scope_v353() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
 IF NEW.linked_event_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.financial_events e WHERE e.id=NEW.linked_event_id AND e.space_id=NEW.space_id) THEN RAISE EXCEPTION 'capture_event_space_mismatch'; END IF; RETURN NEW;END $$;
CREATE TRIGGER folego_capture_scope_v353 BEFORE INSERT OR UPDATE ON public.financial_capture_inbox FOR EACH ROW EXECUTE FUNCTION private.folego_capture_scope_v353();
CREATE FUNCTION private.folego_alert_on_new_financial_event_v353() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE needs_review boolean; category_name text; account_name text; details jsonb; existing boolean;
BEGIN
 IF NEW.status<>'confirmed' OR NEW.event_type NOT IN ('expense','income','transfer','reserve_transfer','card_purchase','card_payment','benefit_expense','benefit_credit','reimbursement','refund','debt_payment') THEN RETURN NEW;END IF;
 -- Never introduce alerts for older events merely edited after installation.
 IF TG_OP='UPDATE' AND OLD.status='confirmed' AND NOT EXISTS(SELECT 1 FROM public.notification_history n WHERE n.stable_key='newTx:'||NEW.id::text) THEN RETURN NEW;END IF;
 SELECT c.name INTO category_name FROM public.categories c WHERE c.id=NEW.category_id;
 SELECT string_agg(DISTINCT a.name,' → ') INTO account_name FROM public.financial_impacts i JOIN public.accounts a ON a.id=i.account_id WHERE i.event_id=NEW.id AND i.dimension='cash';
 needs_review := COALESCE(NEW.metadata->>'needs_classification','false')='true' OR COALESCE(category_name='A classificar',false) OR(NEW.category_id IS NULL AND NEW.event_type IN ('expense','income','card_purchase','benefit_expense'));
 IF account_name IS NULL THEN SELECT cc.name INTO account_name FROM public.credit_cards cc WHERE cc.id::text=NEW.metadata->>'card_id' AND cc.space_id=NEW.space_id;END IF;
 details:=jsonb_build_object('event_id',NEW.id,'amount',NEW.amount,'account',account_name,'occurred_at',NEW.occurred_at,'category',category_name,'description',NEW.description,'needs_review',needs_review,'event_type',NEW.event_type);
 INSERT INTO public.notification_history(user_id,space_id,stable_key,kind,title,body,route,delivered_at,payload)
 SELECT sm.user_id,NEW.space_id,'newTx:'||NEW.id::text,CASE WHEN needs_review THEN 'transactionNeedsReview' ELSE 'newTransaction' END,CASE WHEN needs_review THEN 'Novo lançamento • revisar' ELSE 'Novo lançamento' END,'R$ '||replace(to_char(NEW.amount,'FM9999999990.00'),'.',',')||' · '||left(NEW.description,130),'/transactions/'||NEW.id::text,now(),details
 FROM public.space_members sm LEFT JOIN public.notification_preferences p ON p.user_id=sm.user_id AND p.space_id=sm.space_id WHERE sm.space_id=NEW.space_id AND sm.role IN('owner','admin','member') AND COALESCE(p.transaction_activity_enabled,true)
 ON CONFLICT(user_id,stable_key) DO UPDATE SET kind=EXCLUDED.kind,title=EXCLUDED.title,body=EXCLUDED.body,route=EXCLUDED.route,payload=EXCLUDED.payload;
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN RAISE WARNING 'Folego activity skipped, SQLSTATE %',SQLSTATE;RETURN NEW;END $$;
CREATE TRIGGER folego_new_transaction_alert_v353 AFTER INSERT OR UPDATE OF status,category_id,metadata,description ON public.financial_events FOR EACH ROW EXECUTE FUNCTION private.folego_alert_on_new_financial_event_v353();
-- Accounting RPCs insert cash impacts after the event; refresh its account payload without another alert.
CREATE FUNCTION private.folego_activity_accounts_v353() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.notification_history n SET payload=n.payload||jsonb_build_object('account',(SELECT string_agg(DISTINCT a.name,' → ') FROM public.financial_impacts i JOIN public.accounts a ON a.id=i.account_id WHERE i.event_id=NEW.event_id AND i.dimension='cash')) WHERE n.stable_key='newTx:'||NEW.event_id::text AND n.space_id=NEW.space_id;
 IF NEW.dimension<>'cash' THEN
  UPDATE public.notification_history n SET payload=n.payload||jsonb_build_object('account',(SELECT c.name FROM public.financial_events e JOIN public.credit_cards c ON c.id::text=e.metadata->>'card_id' AND c.space_id=e.space_id WHERE e.id=NEW.event_id)) WHERE n.stable_key='newTx:'||NEW.event_id::text AND n.space_id=NEW.space_id AND n.payload->>'account' IS NULL;
 END IF;
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;END $$;
CREATE TRIGGER folego_activity_accounts_v353 AFTER INSERT ON public.financial_impacts FOR EACH ROW EXECUTE FUNCTION private.folego_activity_accounts_v353();
CREATE FUNCTION private.folego_alert_on_email_review_v353() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.review_status<>'needs_review' THEN RETURN NEW;END IF;
 INSERT INTO public.notification_history(user_id,space_id,stable_key,kind,title,body,route,delivered_at,payload)
 SELECT sm.user_id,NEW.space_id,'capture:'||NEW.id::text,'captureNeedsReview','Revisar comprovante','R$ '||replace(to_char(NEW.amount,'FM9999999990.00'),'.',',')||' · '||COALESCE(NEW.counterparty,NEW.description),'/captures/'||NEW.id::text,now(),jsonb_build_object('capture_id',NEW.id,'amount',NEW.amount,'account','Mercado Pago','occurred_at',NEW.occurred_at,'review_reason',NEW.review_reason,'candidate_event_id',NEW.metadata->>'candidate_event_id','difference',NEW.metadata->'difference')
 FROM public.space_members sm WHERE sm.space_id=NEW.space_id AND sm.role IN('owner','admin','member') ON CONFLICT(user_id,stable_key) DO NOTHING;
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN RAISE WARNING 'Folego receipt alert skipped, SQLSTATE %',SQLSTATE;RETURN NEW;END $$;
CREATE TRIGGER folego_email_capture_alert_v353 AFTER INSERT ON public.financial_capture_inbox FOR EACH ROW EXECUTE FUNCTION private.folego_alert_on_email_review_v353();
REVOKE ALL ON FUNCTION private.folego_capture_scope_v353(),private.folego_alert_on_new_financial_event_v353(),private.folego_activity_accounts_v353(),private.folego_alert_on_email_review_v353() FROM PUBLIC,anon,authenticated;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_history,public.financial_activity_read_state,public.financial_capture_inbox;
COMMENT ON TABLE public.financial_capture_inbox IS 'Staged evidence only, never economic or cash impacts. Trusted ingestion; no client financial confirmation.';

CREATE FUNCTION private.folego_activity_card_label_v353() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN UPDATE public.notification_history n SET payload=n.payload||jsonb_build_object('account',(SELECT c.name FROM public.credit_cards c WHERE c.id=NEW.card_id AND c.space_id=NEW.space_id)) WHERE n.stable_key='newTx:'||NEW.event_id::text AND n.space_id=NEW.space_id;RETURN NEW;EXCEPTION WHEN OTHERS THEN RETURN NEW;END $$;
CREATE TRIGGER folego_activity_card_label_v353 AFTER INSERT ON public.card_purchases FOR EACH ROW EXECUTE FUNCTION private.folego_activity_card_label_v353();
REVOKE ALL ON FUNCTION private.folego_activity_card_label_v353() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.get_financial_activity_unread_count(p_space_id uuid) RETURNS integer LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT count(*)::integer FROM public.notification_history n WHERE n.user_id=(SELECT auth.uid()) AND n.space_id=p_space_id AND (SELECT private.is_space_member(p_space_id)) AND NOT EXISTS(SELECT 1 FROM public.financial_activity_read_state r WHERE r.user_id=(SELECT auth.uid()) AND r.space_id=p_space_id AND r.stable_key=coalesce(nullif(n.stable_key,''),'legacy:'||n.id::text));
$$;
REVOKE ALL ON FUNCTION public.get_financial_activity_unread_count(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_financial_activity_unread_count(uuid) TO authenticated,service_role;
