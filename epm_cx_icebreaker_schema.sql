create extension if not exists pgcrypto;
create extension if not exists vector;

create table prospect_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  company text not null,
  title text,
  target_region text,
  country_code char(2),
  target_type text check (target_type in
    ('epm_partner','sage_partner','cfo','finance_leader','family_office','other')),
  professional_context text,
  identity_status text not null default 'unverified'
    check (identity_status in ('unverified','confirmed','ambiguous','rejected')),
  do_not_contact boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table research_runs (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null references prospect_profiles(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued','running','completed','partial','failed','cancelled')),
  query_plan jsonb not null default '[]'::jsonb,
  provider text not null default 'tavily',
  prompt_version text,
  started_at timestamptz,
  completed_at timestamptz,
  error_code text,
  created_at timestamptz not null default now()
);

create table source_evidence (
  id uuid primary key default gen_random_uuid(),
  research_run_id uuid not null references research_runs(id) on delete cascade,
  prospect_id uuid not null references prospect_profiles(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  url text not null,
  canonical_url text,
  publisher text,
  title text,
  published_at timestamptz,
  retrieved_at timestamptz not null default now(),
  snippet text not null,
  source_type text,
  tavily_score real,
  evidence_class text not null default 'C'
    check (evidence_class in ('A','B','C','rejected')),
  identity_match text not null default 'unverified'
    check (identity_match in ('confirmed','probable','ambiguous','rejected')),
  user_approved boolean not null default false,
  rejection_reason text,
  content_hash text,
  created_at timestamptz not null default now(),
  unique (research_run_id, canonical_url)
);

create table allegory_library (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  title text not null,
  metaphor_body text not null,
  intended_theme text not null,
  suitability_notes text,
  approved boolean not null default false,
  embedding vector(1536),
  created_at timestamptz not null default now()
);

create table generated_deliverables (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null references prospect_profiles(id) on delete cascade,
  research_run_id uuid references research_runs(id) on delete set null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  deliverable_type text not null check (deliverable_type in
    ('research_brief','icebreaker','meeting_guide','product_boundary','follow_up')),
  content jsonb not null,
  evidence_ids uuid[] not null default '{}',
  status text not null default 'draft'
    check (status in ('draft','approved','sent','superseded','rejected')),
  prompt_version text,
  model text,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  sent_at timestamptz
);

create table outreach_events (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null references prospect_profiles(id) on delete cascade,
  deliverable_id uuid references generated_deliverables(id) on delete set null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check (channel in ('email','linkedin','event','meeting','phone','other')),
  event_type text not null,
  occurred_at timestamptz not null default now(),
  next_action text,
  next_action_due_at timestamptz,
  buyer_confirmed_trigger text,
  notes text
);

create table suppression_list (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  email_hash text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  unique (owner_id, email_hash)
);

-- Enable RLS on all user data tables. Add owner_id = auth.uid() policies
-- for select/insert/update/delete. Use service role only inside trusted server.
