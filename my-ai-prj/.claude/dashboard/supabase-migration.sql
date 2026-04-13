-- Chạy file này trong Supabase SQL Editor
-- Dashboard: https://app.supabase.com → SQL Editor

create table if not exists todos (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  status       text not null default 'todo'
                 check (status in ('todo', 'in_progress', 'done', 'blocked')),
  priority     text not null default 'medium'
                 check (priority in ('high', 'medium', 'low')),
  assigned_agent text,
  updated_at   timestamptz not null default now()
);

-- Realtime
alter publication supabase_realtime add table todos;

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger todos_updated_at
  before update on todos
  for each row execute function update_updated_at();

-- Sample data
insert into todos (title, status, priority) values
  ('Setup project structure', 'done', 'high'),
  ('Configure CI/CD', 'in_progress', 'high'),
  ('Write initial tests', 'todo', 'medium');
