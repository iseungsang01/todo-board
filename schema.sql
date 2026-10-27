-- Supabase SQL Editor에서 한 번 실행한다.
-- 할 일과 분류를 (사용자, 묶음, id) 한 줄씩 jsonb로 저장한다. 묶음은 "tasks", "meta".
create table if not exists public.todo_board_docs (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, name, id)
);

alter table public.todo_board_docs enable row level security;
grant select, insert, update, delete on public.todo_board_docs to authenticated;

create policy "todo_board 본인 것만" on public.todo_board_docs
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 다른 기기에서 바꾼 것을 실시간으로 받는다.
alter publication supabase_realtime add table public.todo_board_docs;
