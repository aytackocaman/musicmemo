-- ============================================================================
-- Music Memo — Security fix #2 (CRITICAL): free-tier quota self-reset
-- Date: 2026-10-04
-- Tracking: zz_notes_credentials/security-audit.md (finding #2)
--
-- PROBLEM
--   public.daily_game_counts had INSERT and UPDATE policies for the caller's
--   own row with no restriction on the values, so the free-tier quota could be
--   reset by writing single_player_count = 0. Unlimited free play was possible
--   without touching the subscriptions table at all.
--
--   The client needed write access because it counted games locally in order to
--   use a 3 AM *device-local* game day instead of the server's UTC midnight.
--
-- FIX
--   Counting moves server-side. increment_game_count(text) takes the user id
--   from the caller's JWT (never a parameter) and keys the row on the UTC
--   calendar date. Clients keep read-only access to their own row.
--
--   Companion client change (same commit): DatabaseService.getGameDay() now
--   returns the UTC date so it agrees with the server, and
--   DatabaseService.incrementGameCount() calls the RPC instead of doing a
--   client-side select-then-upsert.
--
--   BEHAVIOUR CHANGE: the daily reset now happens at 00:00 UTC. For the owner's
--   timezone (Europe/Istanbul, UTC+3) that preserves the intended ~3 AM reset.
--   Using a device-local boundary instead would desynchronise client and server
--   for negative UTC offsets and hand out a free reset.
--
--   ROLLBACK
--   Re-add the two permissive policies and restore the client upsert. Only do
--   this together with reverting getGameDay(), or counts will be mis-keyed.
-- ============================================================================

-- ─── Policies ───────────────────────────────────────────────────────────────

drop policy if exists "Users can insert own daily counts" on public.daily_game_counts;
drop policy if exists "Users can update own daily counts" on public.daily_game_counts;
drop policy if exists "Users can view own daily counts"   on public.daily_game_counts;

create policy "Users can view own daily counts"
  on public.daily_game_counts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ─── Grants ─────────────────────────────────────────────────────────────────

revoke all on public.daily_game_counts from anon;

revoke insert, update, delete on public.daily_game_counts from authenticated;

-- ─── Counter function ───────────────────────────────────────────────────────

create or replace function public.increment_game_count(p_game_mode text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_day date := (now() at time zone 'UTC')::date;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  insert into public.daily_game_counts as d
    (user_id, date, single_player_count, local_multiplayer_count)
  values (
    v_uid,
    v_day,
    case when p_game_mode = 'single_player'     then 1 else 0 end,
    case when p_game_mode = 'local_multiplayer' then 1 else 0 end
  )
  on conflict (user_id, date) do update
    set single_player_count     = d.single_player_count     + case when p_game_mode = 'single_player'     then 1 else 0 end,
        local_multiplayer_count = d.local_multiplayer_count + case when p_game_mode = 'local_multiplayer' then 1 else 0 end;
end;
$fn$;

revoke all on function public.increment_game_count(text) from public, anon;
grant execute on function public.increment_game_count(text) to authenticated;

-- ─── Remove the caller-controlled overload ──────────────────────────────────
-- This variant accepted an arbitrary p_user_id and was executable by anon,
-- which allowed anyone to inflate another user's quota and lock them out.

drop function if exists public.increment_game_count(uuid, text);
