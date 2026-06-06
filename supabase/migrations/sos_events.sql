create table if not exists public.sos_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  timestamp   timestamptz not null default now(),
  latitude    double precision,
  longitude   double precision,
  contacts_count integer not null default 0,
  success_count  integer not null default 0,
  failure_count  integer not null default 0
);

alter table public.sos_events enable row level security;

create policy "Users can insert own SOS events"
  on public.sos_events for insert
  with check (auth.uid() = user_id);

create policy "Users can view own SOS events"
  on public.sos_events for select
  using (auth.uid() = user_id);
