-- Preserve full account/space deletion while blocking ordinary linked-event edits.
alter table public.payment_recognitions drop constraint payment_recognitions_event_id_space_id_fkey;
alter table public.payment_recognitions add constraint payment_recognitions_event_id_space_id_fkey
 foreign key(event_id,space_id) references public.financial_events(id,space_id) on delete cascade;
create or replace function private.guard_recognized_payment() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.financial_spaces where id=old.space_id)
 and exists(select 1 from public.payment_recognitions where event_id=old.id and unlinked_at is null)
 and (tg_op='DELETE' or new.status is distinct from old.status or new.amount is distinct from old.amount or new.occurred_at is distinct from old.occurred_at or new.event_type not in ('card_payment','debt_payment') or new.metadata->>'recognized_payment' is distinct from 'true') then
  raise exception 'unlink_recognized_payment_first';
 end if;
 if tg_op='DELETE' then return old; end if; return new;
end; $$;
create or replace function private.guard_recognized_payment_cash() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.financial_spaces where id=old.space_id)
 and exists(select 1 from public.payment_recognitions where event_id=old.event_id and unlinked_at is null) then raise exception 'unlink_recognized_payment_first'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end; $$;
