-- PostgreSQL 17 fixture: synthetic A/B users, independent financial spaces,
-- one legitimate shared viewer and direct import-row permissions matching Dev.
-- This fixture never connects to Supabase and contains no customer records.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA auth, private TO authenticated;

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE SET search_path TO ''
AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;

CREATE TABLE public.financial_spaces(id uuid PRIMARY KEY,owner_id uuid NOT NULL);
CREATE TABLE public.space_members(
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  user_id uuid NOT NULL,
  role text NOT NULL CHECK(role IN ('owner','admin','member','viewer')),
  PRIMARY KEY(space_id,user_id)
);

CREATE FUNCTION private.is_space_member(p_space_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.space_members sm
    WHERE sm.space_id=p_space_id AND sm.user_id=auth.uid()
  )
$$;
CREATE FUNCTION private.can_write_space(p_space_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.space_members sm
    WHERE sm.space_id=p_space_id AND sm.user_id=auth.uid()
      AND sm.role IN ('owner','admin','member')
  )
$$;
REVOKE ALL ON FUNCTION private.is_space_member(uuid),
  private.can_write_space(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_space_member(uuid),
  private.can_write_space(uuid) TO authenticated;

CREATE TABLE public.import_batches(
  id uuid PRIMARY KEY,
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id)
);
CREATE TABLE public.categories(
  id uuid PRIMARY KEY,space_id uuid NOT NULL REFERENCES public.financial_spaces(id)
);
CREATE TABLE public.accounts(
  id uuid PRIMARY KEY,space_id uuid NOT NULL REFERENCES public.financial_spaces(id)
);
CREATE TABLE public.card_invoices(
  id uuid PRIMARY KEY,space_id uuid NOT NULL REFERENCES public.financial_spaces(id)
);
CREATE TABLE public.financial_events(
  id uuid PRIMARY KEY,space_id uuid NOT NULL REFERENCES public.financial_spaces(id)
);
CREATE TABLE public.card_purchases(
  id uuid PRIMARY KEY,space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  event_id uuid NOT NULL REFERENCES public.financial_events(id)
);
CREATE TABLE public.card_payments(
  id uuid PRIMARY KEY,space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  event_id uuid NOT NULL REFERENCES public.financial_events(id)
);

-- Legacy schema's *single-column* FKs intentionally reproduced here;
-- they are insufficient to enforce two-column tenant associations.
CREATE TABLE public.import_rows(
  id uuid PRIMARY KEY,
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  batch_id uuid NOT NULL REFERENCES public.import_batches(id),
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  counterpart_account_id uuid REFERENCES public.accounts(id),
  invoice_id uuid REFERENCES public.card_invoices(id),
  imported_event_id uuid REFERENCES public.financial_events(id),
  status text NOT NULL DEFAULT 'staged'
);

-- Mimic the existing resolver: a valid card purchase/payment backing ID
-- provided on UPDATE is converted into the in-space financial event.
CREATE FUNCTION private.resolve_import_backing_event_id()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_event uuid;
BEGIN
  IF NEW.status <> 'imported' OR NEW.imported_event_id IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT e.id INTO v_event
  FROM public.financial_events e
  WHERE e.id=NEW.imported_event_id AND e.space_id=NEW.space_id;
  IF v_event IS NULL THEN
    SELECT p.event_id INTO v_event
    FROM public.card_purchases p
    WHERE p.id=NEW.imported_event_id AND p.space_id=NEW.space_id;
  END IF;
  IF v_event IS NULL THEN
    SELECT p.event_id INTO v_event
    FROM public.card_payments p
    WHERE p.id=NEW.imported_event_id AND p.space_id=NEW.space_id;
  END IF;
  IF v_event IS NULL THEN
    RAISE EXCEPTION 'import_backing_event_not_found';
  END IF;
  NEW.imported_event_id := v_event;
  RETURN NEW;
END;
$$;
CREATE TRIGGER import_rows_resolve_backing_event_id
BEFORE UPDATE OF status,imported_event_id ON public.import_rows
FOR EACH ROW
WHEN (NEW.status='imported' AND NEW.imported_event_id IS NOT NULL)
EXECUTE FUNCTION private.resolve_import_backing_event_id();

-- Reference tables also hide the second user's rows, as on Supabase Dev.
-- PostgreSQL FK checks still see such hidden rows; RLS alone is not a
-- same-tenant foreign-reference invariant.
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY categories_select_member ON public.categories
FOR SELECT TO authenticated
USING ((SELECT private.is_space_member(categories.space_id)));
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY accounts_select_member ON public.accounts
FOR SELECT TO authenticated
USING ((SELECT private.is_space_member(accounts.space_id)));
ALTER TABLE public.card_invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY card_invoices_select_member ON public.card_invoices
FOR SELECT TO authenticated
USING ((SELECT private.is_space_member(card_invoices.space_id)));
ALTER TABLE public.financial_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY events_select_member ON public.financial_events
FOR SELECT TO authenticated
USING ((SELECT private.is_space_member(financial_events.space_id)));
ALTER TABLE public.import_batches ENABLE ROW LEVEL SECURITY;
CREATE POLICY import_batches_select_member ON public.import_batches
FOR SELECT TO authenticated
USING ((SELECT private.is_space_member(import_batches.space_id)));

-- Match the current Dev import_rows RLS predicate and direct grants.
ALTER TABLE public.import_rows ENABLE ROW LEVEL SECURITY;
CREATE POLICY import_rows_select_member ON public.import_rows
FOR SELECT TO authenticated
USING ((SELECT private.is_space_member(import_rows.space_id)));
CREATE POLICY import_rows_insert_writer ON public.import_rows
FOR INSERT TO authenticated
WITH CHECK (
  (SELECT private.can_write_space(import_rows.space_id))
  AND EXISTS (
    SELECT 1 FROM public.import_batches b
    WHERE b.id=import_rows.batch_id AND b.space_id=import_rows.space_id
  )
);
CREATE POLICY import_rows_update_writer ON public.import_rows
FOR UPDATE TO authenticated
USING ((SELECT private.can_write_space(import_rows.space_id)))
WITH CHECK ((SELECT private.can_write_space(import_rows.space_id)));
GRANT SELECT,INSERT,UPDATE,DELETE ON public.import_rows TO authenticated;
GRANT SELECT ON public.import_batches TO authenticated;
GRANT SELECT ON public.categories,public.accounts,
  public.card_invoices,public.financial_events TO authenticated;

-- Reference fixture entries in the two independent spaces.
INSERT INTO public.financial_spaces(id,owner_id) VALUES
('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
INSERT INTO public.space_members(space_id,user_id,role) VALUES
('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner'),
('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','owner'),
('11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','viewer'),
('11111111-1111-4111-8111-111111111111','cccccccc-cccc-4ccc-8ccc-cccccccccccc','member'),
('11111111-1111-4111-8111-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd','admin');
INSERT INTO public.import_batches(id,space_id) VALUES
('a0000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111'),
('b0000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222');
INSERT INTO public.categories(id,space_id) VALUES
('a0000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111'),
('b0000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222');
INSERT INTO public.accounts(id,space_id) VALUES
('a0000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111'),
('b0000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222');
INSERT INTO public.card_invoices(id,space_id) VALUES
('a0000000-0000-4000-8000-000000000004','11111111-1111-4111-8111-111111111111'),
('b0000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222');
INSERT INTO public.financial_events(id,space_id) VALUES
('a0000000-0000-4000-8000-000000000005','11111111-1111-4111-8111-111111111111'),
('b0000000-0000-4000-8000-000000000005','22222222-2222-4222-8222-222222222222');
INSERT INTO public.card_purchases(id,space_id,event_id) VALUES
('a0000000-0000-4000-8000-000000000006',
 '11111111-1111-4111-8111-111111111111',
 'a0000000-0000-4000-8000-000000000005');
INSERT INTO public.card_payments(id,space_id,event_id) VALUES
('a0000000-0000-4000-8000-000000000007',
 '11111111-1111-4111-8111-111111111111',
 'a0000000-0000-4000-8000-000000000005');
INSERT INTO public.import_rows(id,space_id,batch_id,category_id) VALUES
('a0000000-0000-4000-8000-000000000010',
 '11111111-1111-4111-8111-111111111111',
 'a0000000-0000-4000-8000-000000000001',
 'a0000000-0000-4000-8000-000000000002'),
('b0000000-0000-4000-8000-000000000010',
 '22222222-2222-4222-8222-222222222222',
 'b0000000-0000-4000-8000-000000000001',
 'b0000000-0000-4000-8000-000000000002');

\echo 'PASS: synthetic accounts, owned spaces, shared viewer, pre-migration staging schema ready.'
