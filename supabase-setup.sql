-- ============================================================
-- Lalitpur Holidays — invoicing schema (run ONCE in Supabase SQL Editor)
-- ============================================================
-- Tables:
--   invoices          one row per invoice; key fields as real columns for
--                     reporting/search, full document in `data` (jsonb)
--   company_settings  single row (id = 1) with the shared company profile
--   tour_packages     the package catalog shown on the Packages page
--   invoice_deletions tombstones so deletes propagate to every device

create table if not exists public.company_settings (
  id         int primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id            text primary key,
  number        text,
  customer_name text,
  invoice_date  date,
  total         numeric,
  status        text,
  currency      text,
  saved_at      timestamptz,
  data          jsonb not null,
  updated_at    timestamptz not null default now()
);

create table if not exists public.tour_packages (
  id           text primary key,
  name         text not null,
  duration     text,
  price        numeric not null default 0,
  couple_extra numeric not null default 0,
  dates        text,
  sort_order   int not null default 0,
  updated_at   timestamptz not null default now()
);

create table if not exists public.invoice_deletions (
  id         text primary key,
  deleted_at timestamptz not null default now()
);

-- keep updated_at accurate on every update
create or replace function public.touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end $$ language plpgsql;

drop trigger if exists company_settings_touch on public.company_settings;
create trigger company_settings_touch before update on public.company_settings
  for each row execute function public.touch_updated_at();

drop trigger if exists invoices_touch on public.invoices;
create trigger invoices_touch before update on public.invoices
  for each row execute function public.touch_updated_at();

drop trigger if exists tour_packages_touch on public.tour_packages;
create trigger tour_packages_touch before update on public.tour_packages
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- Row Level Security: Admin (configured email) has full access.
-- Staff (all other authenticated users) have READ-ONLY access to invoices,
-- packages, and company settings. They CANNOT create/edit/delete.
-- ------------------------------------------------------------
alter table public.company_settings  enable row level security;
alter table public.invoices          enable row level security;
alter table public.tour_packages     enable row level security;
alter table public.invoice_deletions enable row level security;

drop policy if exists "staff_company"  on public.company_settings;
drop policy if exists "staff_invoices" on public.invoices;
drop policy if exists "staff_packages" on public.tour_packages;
drop policy if exists "staff_deletions" on public.invoice_deletions;
drop policy if exists "admin_all"      on public.company_settings;
drop policy if exists "admin_all"      on public.invoices;
drop policy if exists "admin_all"      on public.tour_packages;
drop policy if exists "admin_all"      on public.invoice_deletions;

-- STAFF: Read-only access to everything
create policy "staff_company_read"  on public.company_settings
  for select to authenticated using (true);
create policy "staff_invoices_read" on public.invoices
  for select to authenticated using (true);
create policy "staff_packages_read" on public.tour_packages
  for select to authenticated using (true);
create policy "staff_deletions_read" on public.invoice_deletions
  for select to authenticated using (true);

-- ADMIN: Full access (INSERT, UPDATE, DELETE) — uses email check
-- Replace 'admin@lalitpurholidays.com' with your actual admin email(s)
-- You can add multiple emails: auth.jwt() ->> 'email' IN ('admin1@...', 'admin2@...')
create policy "admin_company_all" on public.company_settings
  for all to authenticated
  using (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'))
  with check (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'));

create policy "admin_invoices_all" on public.invoices
  for all to authenticated
  using (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'))
  with check (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'));

create policy "admin_packages_all" on public.tour_packages
  for all to authenticated
  using (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'))
  with check (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'));

create policy "admin_deletions_all" on public.invoice_deletions
  for all to authenticated
  using (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'))
  with check (auth.jwt() ->> 'email' IN ('admin@lalitpurholidays.com'));

-- optional helper: invoices by year (for future reporting)
create index if not exists invoices_number_idx on public.invoices (number);
create index if not exists invoices_date_idx   on public.invoices (invoice_date);