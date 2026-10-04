-- ============================================================================
-- Music Memo — Security fixes #5, #6, #7, #8 and #10
-- Date: 2026-10-04
-- Tracking: zz_notes_credentials/security-audit.md
--
-- #5  MEDIUM  online_sessions UPDATE had no WITH CHECK, and a participant could
--              write any column of their own session.
-- #6  MEDIUM  profiles was readable with USING (true) as the public role, so
--              anyone holding the shipped anon key could enumerate every user's
--              uuid, display_name and avatar_url.
-- #7  MEDIUM  Every policy was created without a TO clause, so all of them also
--              applied to anon.
-- #8  MEDIUM  daily_challenge_scores was readable by anon and accepted a score
--              of any value.
-- #10 LOW     18 policies re-evaluated auth.uid() per row; 20 duplicate-policy
--              warnings; 3 unindexed foreign keys; 1 unused index.
--
-- Also included: handle_new_user is no longer executable by authenticated (a
-- trigger does not need it), and the public catalogue tables are read-only for
-- anon at the grant level rather than relying on RLS alone.
-- ============================================================================


-- ===========================================================================
-- #5 — online_sessions
-- ===========================================================================

drop policy if exists "Players can view own sessions"     on public.online_sessions;
drop policy if exists "Players can update own sessions"   on public.online_sessions;
drop policy if exists "Users can view waiting or own sessions" on public.online_sessions;
drop policy if exists "Users can update own sessions"     on public.online_sessions;
drop policy if exists "Users can create sessions"         on public.online_sessions;
drop policy if exists "Hosts can delete waiting sessions" on public.online_sessions;

create policy "Users can create sessions"
  on public.online_sessions for insert to authenticated
  with check ((select auth.uid()) = player1_id);

-- Public matchmaking relies on being able to see open 'waiting' sessions.
create policy "Users can view waiting or own sessions"
  on public.online_sessions for select to authenticated
  using (
    status = 'waiting'
    or (select auth.uid()) = player1_id
    or (select auth.uid()) = player2_id
  );

create policy "Users can update own sessions"
  on public.online_sessions for update to authenticated
  using (
    (select auth.uid()) = player1_id
    or (select auth.uid()) = player2_id
    or (status = 'waiting' and player2_id is null)
  )
  with check (
    (select auth.uid()) = player1_id
    or (select auth.uid()) = player2_id
    or (status = 'waiting' and player2_id is null)
  );

create policy "Hosts can delete waiting sessions"
  on public.online_sessions for delete to authenticated
  using ((select auth.uid()) = player1_id and status = 'waiting');

revoke all on public.online_sessions from anon;

-- Restrict UPDATE to the columns the app legitimately writes. winner_id is
-- never written by the client, so revoking it removes a cheat vector for free.
revoke update on public.online_sessions from authenticated;
grant update (
  player2_id, player2_name, player1_score, player2_score,
  status, current_turn, game_state,
  player1_left, player2_left, rematch_player1, rematch_player2, updated_at
) on public.online_sessions to authenticated;

-- RESIDUAL RISK (documented, not fixed here): a participant can still set
-- player1_score / player2_score / current_turn to arbitrary values for a session
-- they are in, because those columns are legitimately client-reported. Closing
-- that requires moving state transitions into a validating RPC — a much larger
-- change than an RLS policy.


-- ===========================================================================
-- #6 — profiles
-- ===========================================================================

drop policy if exists "Anyone can view profiles"     on public.profiles;
drop policy if exists "Users can view own profile"   on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

-- Required by the daily-challenge leaderboard, which joins profiles(display_name).
create policy "Authenticated can view profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

revoke all on public.profiles from anon;

-- RESIDUAL RISK: any signed-up user can still enumerate display names. Narrowing
-- further needs a security_invoker view exposing only id + display_name.


-- ===========================================================================
-- #8 — daily_challenge_scores
-- ===========================================================================

drop policy if exists "Anyone can view daily scores"     on public.daily_challenge_scores;
drop policy if exists "Users can insert own daily score" on public.daily_challenge_scores;

create policy "Authenticated can view daily scores"
  on public.daily_challenge_scores for select to authenticated
  using (true);

create policy "Users can insert own daily score"
  on public.daily_challenge_scores for insert to authenticated
  with check ((select auth.uid()) = user_id);

revoke all on public.daily_challenge_scores from anon;

-- Sanity bound. NOT an anti-cheat measure: the score is still client-reported.
alter table public.daily_challenge_scores
  drop constraint if exists daily_challenge_scores_score_range;
alter table public.daily_challenge_scores
  add constraint daily_challenge_scores_score_range
  check (score is null or score between 0 and 100000);


-- ===========================================================================
-- #7 + #10 — explicit roles everywhere, auth.uid() wrapped, dupes removed
-- ===========================================================================

-- Per-user tables: authenticated only.
drop policy if exists "Users can view own games"          on public.games;
create policy "Users can manage own games"
  on public.games for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can view own stats"          on public.user_stats;
create policy "Users can manage own stats"
  on public.user_stats for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can view own category stats" on public.category_stats;
create policy "Users can manage own category stats"
  on public.category_stats for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.games          from anon;
revoke all on public.user_stats     from anon;
revoke all on public.category_stats from anon;

-- Public catalogue: deliberately readable by anon (shipped audio content).
drop policy if exists "Anyone can read category groups"   on public.category_groups;
create policy "Anyone can read category groups"
  on public.category_groups for select to anon, authenticated using (true);

drop policy if exists "Anyone can read sound categories" on public.sound_categories;
create policy "Anyone can read sound categories"
  on public.sound_categories for select to anon, authenticated using (true);

-- 'sounds are publicly readable' duplicated 'Anyone can read sounds'.
drop policy if exists "sounds are publicly readable" on public.sounds;
drop policy if exists "Anyone can read sounds"        on public.sounds;
create policy "Anyone can read sounds"
  on public.sounds for select to anon, authenticated using (true);

drop policy if exists "sound_tags are publicly readable" on public.sound_tags;
create policy "sound_tags are publicly readable"
  on public.sound_tags for select to anon, authenticated using (true);

drop policy if exists "tag_values are publicly readable" on public.tag_values;
create policy "tag_values are publicly readable"
  on public.tag_values for select to anon, authenticated using (true);

-- Read-only for anon at the grant level too, not just via RLS.
revoke insert, update, delete, truncate, references, trigger
  on public.category_groups, public.sound_categories, public.sound_tags,
     public.sounds, public.tag_values
  from anon;


-- ===========================================================================
-- #4 follow-up — a trigger needs no EXECUTE privilege for authenticated
-- ===========================================================================

revoke all on function public.handle_new_user() from authenticated;


-- ===========================================================================
-- #10 — indexes
-- ===========================================================================

create index if not exists idx_online_sessions_winner_id on public.online_sessions (winner_id);
create index if not exists idx_sound_categories_group_id on public.sound_categories (group_id);
create index if not exists idx_sounds_category_id        on public.sounds (category_id);

drop index if exists public.idx_games_game_mode;
