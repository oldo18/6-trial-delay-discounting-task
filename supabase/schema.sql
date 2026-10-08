-- Supabase schema for the 6-trial delay discounting task.
-- Run once in Supabase -> SQL Editor.

create extension if not exists pgcrypto;

-- One row per finished task. The full response is kept in payload; the main
-- outcome variables are also exposed as generated columns for easy export.
create table if not exists public.ddt_responses (
  id uuid primary key default gen_random_uuid(),
  participant_id text not null unique,
  study_id text,
  created_at timestamptz not null default now(),
  submitted_at timestamptz not null default now(),
  payload jsonb not null,
  dd_k numeric generated always as ((payload->>'dd_k')::numeric) stored,
  dd_log10_k numeric generated always as ((payload->>'dd_log10_k')::numeric) stored,
  dd_ed50_days numeric generated always as ((payload->>'dd_ed50_days')::numeric) stored,
  dd_attention_triggered boolean generated always as ((payload->>'dd_attention_triggered')::boolean) stored,
  dd_attention_passed boolean generated always as ((payload->>'dd_attention_passed')::boolean) stored,
  dd_flag_too_fast boolean generated always as ((payload->>'dd_flag_too_fast')::boolean) stored
);

-- Used by api/submit.js to limit the number of submissions per IP address.
create table if not exists public.rate_limit_log (
  id uuid primary key default gen_random_uuid(),
  ip text not null,
  created_at timestamptz not null default now()
);

create index if not exists ddt_responses_study_id_idx on public.ddt_responses (study_id);
create index if not exists rate_limit_log_ip_created_idx on public.rate_limit_log (ip, created_at);

-- Row level security is enabled without any policies, so the public (anon)
-- key can neither read nor write. Only the server function, which uses the
-- service role key, can insert rows.
alter table public.ddt_responses enable row level security;
alter table public.rate_limit_log enable row level security;

-- Flat view for exporting to CSV (Table Editor or SQL Editor -> Export).
create or replace view public.ddt_export
with (security_invoker = true) as
select
  participant_id,
  study_id,
  submitted_at,
  payload->>'currency' as currency,
  (payload->>'amount_eur')::numeric as amount_eur,
  dd_k,
  dd_log10_k,
  dd_ed50_days,
  dd_attention_triggered,
  payload->>'dd_attention_type' as dd_attention_type,
  dd_attention_passed,
  (payload->>'dd_min_rt_ms')::int as dd_min_rt_ms,
  dd_flag_too_fast,
  (payload->>'dd_t1_node')::int as dd_t1_node, payload->>'dd_t1_choice' as dd_t1_choice, (payload->>'dd_t1_rt_ms')::int as dd_t1_rt_ms,
  (payload->>'dd_t2_node')::int as dd_t2_node, payload->>'dd_t2_choice' as dd_t2_choice, (payload->>'dd_t2_rt_ms')::int as dd_t2_rt_ms,
  (payload->>'dd_t3_node')::int as dd_t3_node, payload->>'dd_t3_choice' as dd_t3_choice, (payload->>'dd_t3_rt_ms')::int as dd_t3_rt_ms,
  (payload->>'dd_t4_node')::int as dd_t4_node, payload->>'dd_t4_choice' as dd_t4_choice, (payload->>'dd_t4_rt_ms')::int as dd_t4_rt_ms,
  (payload->>'dd_t5_node')::int as dd_t5_node, payload->>'dd_t5_choice' as dd_t5_choice, (payload->>'dd_t5_rt_ms')::int as dd_t5_rt_ms,
  payload->>'dd_t6_kind' as dd_t6_kind,
  (payload->>'dd_t6_node')::int as dd_t6_node, payload->>'dd_t6_choice' as dd_t6_choice, (payload->>'dd_t6_rt_ms')::int as dd_t6_rt_ms
from public.ddt_responses;
