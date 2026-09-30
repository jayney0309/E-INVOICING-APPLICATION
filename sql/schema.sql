-- ============================================================================
-- Invoicing App — Supabase schema
-- Multi-tenant: each "business" is a tenant. Users join a business via
-- business_members. All data tables are scoped by business_id and locked
-- down with Row Level Security so one business can never see another's data.
--
-- HOW TO USE: Paste this whole file into the Supabase SQL Editor (your
-- project > SQL Editor > New query) and click Run. It is safe to re-run
-- (uses IF NOT EXISTS / CREATE OR REPLACE where possible), but on a brand
-- new project just run it once.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- businesses: one row per client business (tenant). Holds the info that
-- appears on every invoice header and drives VAT vs Non-VAT formatting.
-- ----------------------------------------------------------------------------
create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tin text,                                  -- 9-digit BIR TIN, no dashes, e.g. 123456789
  branch_code text not null default '00000', -- BIR branch code, head office = 00000
  address text,
  vat_registered boolean not null default false,
  invoice_prefix text not null default 'INV',
  next_invoice_seq integer not null default 1,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- business_members: which auth users can access which business, and as what
-- role. 'owner' can manage settings/members; 'staff' can create invoices.
-- ----------------------------------------------------------------------------
create table if not exists business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner', 'staff')),
  created_at timestamptz not null default now(),
  unique (business_id, user_id)
);

-- member_email: a snapshot of the member's email, stored here so the app can
-- show a team list without ever querying auth.users directly from the
-- client (Supabase locks that down for privacy/security reasons).
alter table business_members add column if not exists member_email text;

-- One-time backfill for members added before this column existed — this
-- UPDATE runs with the elevated access the SQL Editor has, so it can read
-- auth.users just this once; the app itself never does.
update business_members bm set member_email = u.email
  from auth.users u
  where bm.user_id = u.id and bm.member_email is null;

-- ----------------------------------------------------------------------------
-- business_invites: "invite someone@email.com to this business" — created
-- before the invitee necessarily has an account. fn_accept_pending_invites()
-- turns a matching invite into a real business_members row the moment that
-- email signs in (whether they already had an account or just made one).
-- ----------------------------------------------------------------------------
create table if not exists business_invites (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  email text not null,
  role text not null default 'staff' check (role in ('owner', 'staff')),
  invited_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  unique (business_id, email)
);

-- ----------------------------------------------------------------------------
-- customers: a business's buyers. Snapshotted onto each invoice at issue
-- time (see invoices table) so editing a customer never rewrites history.
-- ----------------------------------------------------------------------------
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name text not null,
  tin text,
  address text,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- invoices: header row. Amounts are stored (not just computed on read) so a
-- later change to the business's VAT rate never changes a past invoice.
-- ----------------------------------------------------------------------------
create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  invoice_no text not null,
  customer_id uuid references customers(id) on delete set null,
  customer_name_snapshot text not null,
  customer_tin_snapshot text,
  customer_address_snapshot text,
  issue_date date not null default current_date,
  vat_registered_snapshot boolean not null,
  gross_amount numeric(14,2) not null default 0,
  vat_amount numeric(14,2) not null default 0,
  net_of_vat numeric(14,2) not null default 0,
  status text not null default 'issued' check (status in ('issued', 'void')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (business_id, invoice_no)
);

-- vat_treatment: only meaningful when vat_registered_snapshot is true.
-- 'standard' = normal 12% VAT. 'zero_rated' / 'exempt' = 0% VAT, but BIR
-- requires the invoice to be explicitly stamped as such (handled in the
-- app's printable view) — they're kept as separate values (rather than
-- both just meaning "no VAT") because they have different consequences for
-- the seller's input VAT credit, which matters for your own records even
-- though this app doesn't track input VAT itself.
alter table invoices add column if not exists vat_treatment text not null default 'standard'
  check (vat_treatment in ('standard', 'zero_rated', 'exempt'));

-- ----------------------------------------------------------------------------
-- invoice_items: line items for an invoice.
-- ----------------------------------------------------------------------------
create table if not exists invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  description text not null,
  qty numeric(12,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  line_total numeric(14,2) not null default 0,
  sort_order integer not null default 0
);

create index if not exists idx_business_members_user on business_members(user_id);
create index if not exists idx_customers_business on customers(business_id);
create index if not exists idx_invoices_business on invoices(business_id);
create index if not exists idx_invoice_items_invoice on invoice_items(invoice_id);

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table businesses enable row level security;
alter table business_members enable row level security;
alter table business_invites enable row level security;
alter table customers enable row level security;
alter table invoices enable row level security;
alter table invoice_items enable row level security;

-- Small helper: is the current user a member of this business?
create or replace function is_business_member(target_business_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from business_members
    where business_id = target_business_id
      and user_id = auth.uid()
  );
$$;

-- businesses: members can see/update their own business; any signed-in user
-- can create a new business (they become its first owner via the app logic).
drop policy if exists businesses_select on businesses;
create policy businesses_select on businesses
  for select using (is_business_member(id));

drop policy if exists businesses_insert on businesses;
create policy businesses_insert on businesses
  for insert with check (auth.uid() is not null);

drop policy if exists businesses_update on businesses;
create policy businesses_update on businesses
  for update using (is_business_member(id));

-- business_members: members can see who else is on their business.
-- Row creation goes through the fn_create_business function (security
-- definer) so a brand-new business can add its first owner.
drop policy if exists business_members_select on business_members;
create policy business_members_select on business_members
  for select using (is_business_member(business_id));

drop policy if exists business_members_insert on business_members;
create policy business_members_insert on business_members
  for insert with check (is_business_member(business_id));

drop policy if exists business_members_delete on business_members;
create policy business_members_delete on business_members
  for delete using (is_business_member(business_id));

-- business_invites: members can see/create/cancel invites for their own
-- business. There is deliberately no policy letting anyone read another
-- business's invites or see which emails have accounts elsewhere.
drop policy if exists business_invites_select on business_invites;
create policy business_invites_select on business_invites
  for select using (is_business_member(business_id));

drop policy if exists business_invites_insert on business_invites;
create policy business_invites_insert on business_invites
  for insert with check (is_business_member(business_id));

drop policy if exists business_invites_delete on business_invites;
create policy business_invites_delete on business_invites
  for delete using (is_business_member(business_id));

-- customers
drop policy if exists customers_all on customers;
create policy customers_all on customers
  for all using (is_business_member(business_id))
  with check (is_business_member(business_id));

-- invoices: no update/delete policy on purpose — invoices are void'd, not
-- edited or deleted, once issued (see fn_void_invoice below).
drop policy if exists invoices_select on invoices;
create policy invoices_select on invoices
  for select using (is_business_member(business_id));

drop policy if exists invoices_insert on invoices;
create policy invoices_insert on invoices
  for insert with check (is_business_member(business_id));

drop policy if exists invoices_void on invoices;
create policy invoices_void on invoices
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

-- invoice_items: access follows the parent invoice's business.
drop policy if exists invoice_items_select on invoice_items;
create policy invoice_items_select on invoice_items
  for select using (
    exists (
      select 1 from invoices
      where invoices.id = invoice_items.invoice_id
        and is_business_member(invoices.business_id)
    )
  );

drop policy if exists invoice_items_insert on invoice_items;
create policy invoice_items_insert on invoice_items
  for insert with check (
    exists (
      select 1 from invoices
      where invoices.id = invoice_items.invoice_id
        and is_business_member(invoices.business_id)
    )
  );

-- ============================================================================
-- Functions: create business (+ owner), and create invoice atomically
-- (so two people issuing an invoice at the same moment never collide on
-- the same invoice number).
-- ============================================================================

create or replace function fn_create_business(
  p_name text,
  p_tin text,
  p_address text,
  p_vat_registered boolean,
  p_invoice_prefix text
) returns uuid
language plpgsql
security definer
as $$
declare
  v_business_id uuid;
begin
  insert into businesses (name, tin, address, vat_registered, invoice_prefix, created_by)
  values (p_name, p_tin, p_address, p_vat_registered, coalesce(nullif(p_invoice_prefix, ''), 'INV'), auth.uid())
  returning id into v_business_id;

  insert into business_members (business_id, user_id, role, member_email)
  values (v_business_id, auth.uid(), 'owner', lower(auth.jwt() ->> 'email'));

  return v_business_id;
end;
$$;

-- Call this once per sign-in (the app does this automatically) so any
-- invite waiting for the signed-in user's email turns into real access.
-- Safe to call repeatedly — already-accepted invites are skipped.
create or replace function fn_accept_pending_invites()
returns integer
language plpgsql
security definer
as $$
declare
  v_email text := lower(auth.jwt() ->> 'email');
  v_invite record;
  v_count integer := 0;
begin
  if v_email is null then
    return 0;
  end if;

  for v_invite in
    select * from business_invites
    where lower(email) = v_email and accepted_at is null
  loop
    insert into business_members (business_id, user_id, role, member_email)
    values (v_invite.business_id, auth.uid(), v_invite.role, v_email)
    on conflict (business_id, user_id) do nothing;

    update business_invites set accepted_at = now() where id = v_invite.id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- Drop the older 7-argument version of this function if it exists (from
-- before the vat_treatment parameter was added) — CREATE OR REPLACE only
-- replaces a function with an IDENTICAL argument list; a changed argument
-- list otherwise creates a second overloaded function instead of replacing
-- the old one, which breaks callers with "function ... is not unique".
drop function if exists fn_create_invoice(uuid, uuid, text, text, text, date, jsonb);

-- p_items is a JSON array of {description, qty, unit_price}.
create or replace function fn_create_invoice(
  p_business_id uuid,
  p_customer_id uuid,
  p_customer_name text,
  p_customer_tin text,
  p_customer_address text,
  p_issue_date date,
  p_items jsonb,
  p_vat_treatment text default 'standard'
) returns uuid
language plpgsql
security definer
as $$
declare
  v_invoice_id uuid;
  v_invoice_no text;
  v_seq integer;
  v_prefix text;
  v_vat_registered boolean;
  v_vat_rate numeric := 0.12;
  v_gross numeric := 0;
  v_vat numeric := 0;
  v_net numeric := 0;
  v_item jsonb;
  v_line_total numeric;
  v_sort integer := 0;
  v_treatment text := coalesce(p_vat_treatment, 'standard');
begin
  if not is_business_member(p_business_id) then
    raise exception 'not a member of this business';
  end if;

  if v_treatment not in ('standard', 'zero_rated', 'exempt') then
    raise exception 'invalid vat_treatment: %', v_treatment;
  end if;

  -- lock the business row so concurrent invoice creation can't reuse a seq
  select next_invoice_seq, invoice_prefix, vat_registered
    into v_seq, v_prefix, v_vat_registered
    from businesses where id = p_business_id
    for update;

  update businesses set next_invoice_seq = v_seq + 1 where id = p_business_id;
  v_invoice_no := v_prefix || '-' || lpad(v_seq::text, 6, '0');

  -- sum line items first (gross)
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_line_total := round((v_item->>'qty')::numeric * (v_item->>'unit_price')::numeric, 2);
    v_gross := v_gross + v_line_total;
  end loop;

  if v_vat_registered and v_treatment = 'standard' then
    v_vat := round(v_gross - (v_gross / (1 + v_vat_rate)), 2);
    v_net := v_gross - v_vat;
  else
    -- non-VAT business, or a VAT-registered business's zero-rated/exempt sale
    v_vat := 0;
    v_net := v_gross;
  end if;

  -- a non-VAT business has no VAT treatment to speak of; always record
  -- 'standard' for it so the column stays meaningful only where it applies
  if not v_vat_registered then
    v_treatment := 'standard';
  end if;

  insert into invoices (
    business_id, invoice_no, customer_id, customer_name_snapshot,
    customer_tin_snapshot, customer_address_snapshot, issue_date,
    vat_registered_snapshot, gross_amount, vat_amount, net_of_vat,
    vat_treatment, created_by
  ) values (
    p_business_id, v_invoice_no, p_customer_id, p_customer_name,
    p_customer_tin, p_customer_address, coalesce(p_issue_date, current_date),
    v_vat_registered, v_gross, v_vat, v_net, v_treatment, auth.uid()
  ) returning id into v_invoice_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_line_total := round((v_item->>'qty')::numeric * (v_item->>'unit_price')::numeric, 2);
    insert into invoice_items (invoice_id, description, qty, unit_price, line_total, sort_order)
    values (
      v_invoice_id,
      v_item->>'description',
      (v_item->>'qty')::numeric,
      (v_item->>'unit_price')::numeric,
      v_line_total,
      v_sort
    );
    v_sort := v_sort + 1;
  end loop;

  return v_invoice_id;
end;
$$;

create or replace function fn_void_invoice(p_invoice_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_business_id uuid;
begin
  select business_id into v_business_id from invoices where id = p_invoice_id;
  if v_business_id is null or not is_business_member(v_business_id) then
    raise exception 'not authorized';
  end if;
  update invoices set status = 'void' where id = p_invoice_id;
end;
$$;
