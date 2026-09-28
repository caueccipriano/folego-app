-- An isolated PostgreSQL fixture. All identities and finances are invented.
-- Deliberately mirror the LIVE foreign-key delete actions without reading any
-- personal financial tables or creating users in linked Supabase Dev.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text NOT NULL UNIQUE
);

CREATE TABLE public.financial_spaces (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text NOT NULL
);

CREATE TABLE public.space_members (
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL,
  PRIMARY KEY(space_id,user_id)
);

CREATE TABLE public.automation_rules (
  id uuid PRIMARY KEY,
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  title text
);

-- A owns a personal space; B shares a household with member C;
-- D is a sole owner of a household, and E is unrelated.
INSERT INTO auth.users(id,email) VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a@synthetic.invalid'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b@synthetic.invalid'),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','c@synthetic.invalid'),
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','d@synthetic.invalid'),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','e@synthetic.invalid');

INSERT INTO public.financial_spaces(id,owner_id,name,type) VALUES
('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A private','personal'),
('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','B shared','household'),
('33333333-3333-4333-8333-333333333333','dddddddd-dddd-4ddd-8ddd-dddddddddddd','D empty household','household'),
('55555555-5555-4555-8555-555555555555','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','E independent','personal');

INSERT INTO public.space_members(space_id,user_id,role) VALUES
('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner'),
('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','owner'),
('22222222-2222-4222-8222-222222222222','cccccccc-cccc-4ccc-8ccc-cccccccccccc','member'),
('33333333-3333-4333-8333-333333333333','dddddddd-dddd-4ddd-8ddd-dddddddddddd','owner'),
('55555555-5555-4555-8555-555555555555','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','owner');

INSERT INTO public.automation_rules(id,space_id,created_by,title) VALUES
('10000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A authored'),
('10000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','B authored'),
('10000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222','cccccccc-cccc-4ccc-8ccc-cccccccccccc','C authored');

\echo 'PASS: only fictional users, private/shared spaces and authored rules seeded.'
