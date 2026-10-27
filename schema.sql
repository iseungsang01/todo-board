-- Supabase SQL Editor에서 한 번 실행한다.
-- 할일판은 on-my-plate(planner) 계정을 그대로 쓴다. 로그인은 planner-api의 /api/auth/login이 하고,
-- 여기 함수들은 그 세션 토큰을 planner_sessions에서 확인만 한다(planner 표는 읽기만 하고 바꾸지 않는다).
-- todo_board_docs는 RLS만 켜고 정책을 두지 않아 직접은 못 읽고, 아래 todo_board_* 함수로만 드나든다.
create extension if not exists pgcrypto with schema extensions;

-- 할 일과 분류를 (planner 사용자, 묶음, id) 한 줄씩 jsonb로 저장한다. 묶음은 "tasks", "meta".
create table if not exists public.todo_board_docs (
  user_id text not null,
  name text not null,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, name, id)
);
alter table public.todo_board_docs enable row level security;

-- planner-api와 같은 방식(sha256 hex)으로 토큰을 해시해 살아 있는 세션의 사용자를 돌려준다.
create or replace function public.todo_board_user(p_token text) returns text
language plpgsql stable security definer set search_path = public, extensions as $$
declare u text;
begin
  select s.user_id into u from planner_sessions s
  where s.token_hash = encode(digest(p_token, 'sha256'), 'hex') and s.revoked_at is null and s.expires_at > now();
  if u is null then raise exception 'bad_token'; end if;
  return u;
end $$;

create or replace function public.todo_board_load(p_token text) returns table (name text, id text, data jsonb)
language plpgsql security definer set search_path = public as $$
declare u text := todo_board_user(p_token); -- 표가 비어 있어도 토큰은 꼭 확인
begin
  return query select d.name, d.id, d.data from todo_board_docs d where d.user_id = u;
end $$;

-- p_rows: [{name, id, data}, ...]
create or replace function public.todo_board_save(p_token text, p_rows jsonb) returns void
language sql security definer set search_path = public as $$
  insert into todo_board_docs (user_id, name, id, data, updated_at)
  select todo_board_user(p_token), r->>'name', r->>'id', r->'data', now() from jsonb_array_elements(p_rows) r
  on conflict (user_id, name, id) do update set data = excluded.data, updated_at = now();
$$;

create or replace function public.todo_board_remove(p_token text, p_name text, p_id text) returns void
language sql security definer set search_path = public as $$
  delete from todo_board_docs where user_id = todo_board_user(p_token) and name = p_name and id = p_id;
$$;

revoke all on function public.todo_board_user(text) from public, anon, authenticated;
revoke all on function public.todo_board_load(text), public.todo_board_save(text, jsonb), public.todo_board_remove(text, text, text) from public;
grant execute on function public.todo_board_load(text), public.todo_board_save(text, jsonb), public.todo_board_remove(text, text, text) to anon, authenticated;
