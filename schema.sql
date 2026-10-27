-- Supabase SQL Editor에서 한 번 실행한다.
-- 할일판은 Supabase Auth(planner와 같이 쓰는 사용자 목록)를 쓰지 않고 자기 표로 아이디·비밀번호를 확인한다.
-- 표는 RLS만 켜고 정책을 두지 않아 직접은 못 읽고, 아래 todo_board_* 함수로만 드나든다.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.todo_board_users (
  username text primary key,
  pw_hash text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.todo_board_sessions (
  token uuid primary key default gen_random_uuid(),
  username text not null references public.todo_board_users on delete cascade,
  created_at timestamptz not null default now()
);
-- 할 일과 분류를 (사용자, 묶음, id) 한 줄씩 jsonb로 저장한다. 묶음은 "tasks", "meta".
create table if not exists public.todo_board_docs (
  username text not null references public.todo_board_users on delete cascade,
  name text not null,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (username, name, id)
);
alter table public.todo_board_users enable row level security;
alter table public.todo_board_sessions enable row level security;
alter table public.todo_board_docs enable row level security;

create or replace function public.todo_board_signup(p_username text, p_password text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare t uuid;
begin
  begin
    insert into todo_board_users (username, pw_hash) values (p_username, crypt(p_password, gen_salt('bf')));
  exception when unique_violation then
    raise exception 'username_taken';
  end;
  insert into todo_board_sessions (username) values (p_username) returning token into t;
  return t;
end $$;

create or replace function public.todo_board_login(p_username text, p_password text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare t uuid;
begin
  if not exists (select 1 from todo_board_users where username = p_username and pw_hash = crypt(p_password, pw_hash)) then
    raise exception 'bad_login';
  end if;
  insert into todo_board_sessions (username) values (p_username) returning token into t;
  return t;
end $$;

create or replace function public.todo_board_user(p_token uuid) returns text
language plpgsql security definer set search_path = public as $$
declare u text;
begin
  select username into u from todo_board_sessions where token = p_token;
  if u is null then raise exception 'bad_token'; end if;
  return u;
end $$;

create or replace function public.todo_board_load(p_token uuid) returns table (name text, id text, data jsonb)
language plpgsql security definer set search_path = public as $$
declare u text := todo_board_user(p_token); -- 표가 비어 있어도 토큰은 꼭 확인
begin
  return query select d.name, d.id, d.data from todo_board_docs d where d.username = u;
end $$;

-- p_rows: [{name, id, data}, ...]
create or replace function public.todo_board_save(p_token uuid, p_rows jsonb) returns void
language sql security definer set search_path = public as $$
  insert into todo_board_docs (username, name, id, data, updated_at)
  select todo_board_user(p_token), r->>'name', r->>'id', r->'data', now() from jsonb_array_elements(p_rows) r
  on conflict (username, name, id) do update set data = excluded.data, updated_at = now();
$$;

create or replace function public.todo_board_remove(p_token uuid, p_name text, p_id text) returns void
language sql security definer set search_path = public as $$
  delete from todo_board_docs where username = todo_board_user(p_token) and name = p_name and id = p_id;
$$;

create or replace function public.todo_board_logout(p_token uuid) returns void
language sql security definer set search_path = public as $$
  delete from todo_board_sessions where token = p_token;
$$;

revoke all on function public.todo_board_user(uuid) from public, anon, authenticated;
revoke all on function
  public.todo_board_signup(text, text), public.todo_board_login(text, text), public.todo_board_load(uuid),
  public.todo_board_save(uuid, jsonb), public.todo_board_remove(uuid, text, text), public.todo_board_logout(uuid)
  from public;
grant execute on function
  public.todo_board_signup(text, text), public.todo_board_login(text, text), public.todo_board_load(uuid),
  public.todo_board_save(uuid, jsonb), public.todo_board_remove(uuid, text, text), public.todo_board_logout(uuid)
  to anon, authenticated;
