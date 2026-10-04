-- ============================================================================
-- Music Memo — Security fixes #3, #4 and #11: SECURITY DEFINER functions
-- Date: 2026-10-04
-- Tracking: zz_notes_credentials/security-audit.md (findings #3, #4, #11)
--
-- PROBLEM
--   public.can_play_game(p_user_id uuid, p_game_mode text) was SECURITY DEFINER
--   in the exposed public schema, and Postgres grants EXECUTE on functions to
--   PUBLIC by default. It was therefore reachable **unauthenticated** via
--   /rest/v1/rpc/can_play_game with an arbitrary p_user_id, which allowed:
--     * inflating another user's daily quota and locking them out of free play;
--     * probing whether an arbitrary user is a subscriber, plus their counts.
--   It also disagreed with the client, which treats 'trial' as premium.
--
--   public.handle_new_user() was SECURITY DEFINER with a mutable search_path
--   (advisor: function_search_path_mutable).
--
-- FIX
--   can_play_game is rebuilt with no caller-supplied user id, granted to
--   authenticated only, and converted to SECURITY INVOKER: both tables it reads
--   are already readable by the caller for their own row, so DEFINER bought
--   nothing and only widened the attack surface.
--
--   handle_new_user keeps SECURITY DEFINER (it is a trigger and must write to
--   tables the caller cannot) but gets a pinned, empty search_path. Every name
--   in its body is already schema-qualified or lives in pg_catalog.
--
--   NOTE the daily limits are duplicated as constants here and, separately, as
--   compile-time dart-define values in lib/config/game_config.dart. Keep them
--   in sync — see "Open decisions" item 2 in the audit.
-- ============================================================================

-- ─── can_play_game ──────────────────────────────────────────────────────────

create or replace function public.can_play_game(p_game_mode text)
returns boolean
language plpgsql
stable
set search_path = public
as $fn$
declare
  v_plan  text;
  v_count integer;
  v_limit integer;
  v_uid   uuid := auth.uid();
  v_day   date := (now() at time zone 'UTC')::date;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  select s.plan into v_plan
    from public.subscriptions s
   where s.user_id = v_uid;

  -- Premium, including trial, has no daily limits.
  if v_plan in ('monthly', 'yearly', 'trial') then
    return true;
  end if;

  -- Online multiplayer is premium-only.
  if p_game_mode = 'online_multiplayer' then
    return false;
  end if;

  -- Must match GameConfig.singlePlayerDailyLimit / localMultiplayerDailyLimit.
  v_limit := case p_game_mode
               when 'single_player'     then 5
               when 'local_multiplayer' then 3
               else null
             end;

  if v_limit is null then
    return false;
  end if;

  select case p_game_mode
           when 'single_player'     then coalesce(max(d.single_player_count), 0)
           when 'local_multiplayer' then coalesce(max(d.local_multiplayer_count), 0)
         end
    into v_count
    from public.daily_game_counts d
   where d.user_id = v_uid
     and d.date = v_day;

  return coalesce(v_count, 0) < v_limit;
end;
$fn$;

revoke all on function public.can_play_game(text) from public, anon;
grant execute on function public.can_play_game(text) to authenticated;

-- Remove the caller-controlled overload.
drop function if exists public.can_play_game(uuid, text);

-- ─── handle_new_user ────────────────────────────────────────────────────────
-- Remains SECURITY DEFINER (trigger). Pin the search path and stop anon from
-- resolving it, even though Postgres will not let a trigger function be called
-- directly through PostgREST.

alter function public.handle_new_user() set search_path = '';

revoke all on function public.handle_new_user() from public, anon;
