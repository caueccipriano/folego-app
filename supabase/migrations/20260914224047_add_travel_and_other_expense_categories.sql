-- Keep the expense taxonomy explicit for travel and catch-all spending.

update public.categories c
set name = 'Outros',
    active = true,
    color_hex = coalesce(c.color_hex, '#8C8CA8'),
    updated_at = now()
where c.kind = 'expense'
  and c.parent_id is null
  and c.name = 'Outros gastos'
  and not exists (
    select 1
    from public.categories existing
    where existing.space_id = c.space_id
      and existing.kind = 'expense'
      and existing.parent_id is null
      and existing.name = 'Outros'
  );

insert into public.categories(space_id, name, kind, essential, color_hex, active)
select fs.id, category.name, 'expense', false, category.color_hex, true
from public.financial_spaces fs
cross join (values
  ('Viagens'::text, '#00BFD1'::text),
  ('Outros'::text, '#8C8CA8'::text)
) as category(name, color_hex)
on conflict (space_id, kind, name) where parent_id is null
do update
set active = true,
    color_hex = coalesce(public.categories.color_hex, excluded.color_hex),
    updated_at = now();

create or replace function private.seed_default_categories()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  insert into public.categories (space_id, name, kind, essential)
  values
    (new.id, 'A classificar', 'expense', false),
    (new.id, 'Supermercado', 'expense', true),
    (new.id, 'Restaurantes', 'expense', false),
    (new.id, 'Delivery', 'expense', false),
    (new.id, 'Transporte', 'expense', true),
    (new.id, 'Gasolina', 'expense', true),
    (new.id, 'Farmácia', 'expense', true),
    (new.id, 'Saúde', 'expense', true),
    (new.id, 'Educação', 'expense', true),
    (new.id, 'Internet/Telefone', 'expense', true),
    (new.id, 'Assinaturas', 'expense', false),
    (new.id, 'Lazer', 'expense', false),
    (new.id, 'Beleza', 'expense', false),
    (new.id, 'Vestuário', 'expense', false),
    (new.id, 'Compras online', 'expense', false),
    (new.id, 'Presentes', 'expense', false),
    (new.id, 'Moradia', 'expense', true),
    (new.id, 'Energia', 'expense', true),
    (new.id, 'Água', 'expense', true),
    (new.id, 'Empréstimos', 'expense', true),
    (new.id, 'Tarifas bancárias', 'expense', false),
    (new.id, 'Viagens', 'expense', false),
    (new.id, 'Outros', 'expense', false),
    (new.id, 'Adiantamento', 'income', false),
    (new.id, 'Bonificação', 'income', false),
    (new.id, 'Comissões', 'income', false),
    (new.id, 'Freelance', 'income', false),
    (new.id, 'Outras receitas', 'income', false),
    (new.id, 'Presente recebido', 'income', false),
    (new.id, 'Rendimentos', 'income', false),
    (new.id, 'Salário', 'income', false),
    (new.id, 'Trabalho extra', 'income', false),
    (new.id, 'Venda', 'income', false),
    (new.id, 'Transferências', 'transfer', false),
    (new.id, 'Reserva', 'transfer', false),
    (new.id, 'Reembolso', 'adjustment', false);
  return new;
end;
$function$;

create or replace function public.ensure_app_categories(p_space_id uuid)
returns void
language plpgsql
set search_path to ''
as $function$
begin
  if auth.uid() is null or not private.can_write_space(p_space_id) then
    raise exception 'write_access_denied';
  end if;

  insert into public.categories(space_id,name,kind,essential,color_hex)
  select p_space_id,name,'expense',essential,color from (values
    ('Alimentação',false,'#2145FF'),
    ('Assinaturas e serviços',false,'#00BFD1'),
    ('Compras',false,'#FF8738'),
    ('Cuidados pessoais',false,'#DB44FF'),
    ('Educação',false,'#FFC247'),
    ('Família e pets',false,'#00BFD1'),
    ('Lazer',false,'#934BFF'),
    ('Moradia',true,'#934BFF'),
    ('Outros',false,'#8C8CA8'),
    ('Saúde',true,'#F451B6'),
    ('Transporte',false,'#D3FF62'),
    ('Viagens',false,'#00BFD1'),
    ('A classificar',false,'#8C8CA8')
  ) v(name,essential,color)
  on conflict(space_id,name) do nothing;

  insert into public.categories(space_id,name,kind,essential,color_hex)
  select p_space_id,name,'income',false,color from (values
    ('Adiantamento','#8B68F6'),
    ('Bonificação','#C6F135'),
    ('Comissões','#E15B8F'),
    ('Freelance','#6C3BF0'),
    ('Outras receitas','#77747C'),
    ('Presente recebido','#E15B8F'),
    ('Rendimentos','#75A83B'),
    ('Salário','#2145FF'),
    ('Trabalho extra','#00BFD1'),
    ('Venda','#FF8738')
  ) v(name,color)
  on conflict(space_id,name) do nothing;
end;
$function$;
