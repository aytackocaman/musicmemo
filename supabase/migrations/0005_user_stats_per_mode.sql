-- ============================================================================
-- Music Memo — Statistics per game mode
-- Date: 2026-10-04
--
-- PROBLEM
--   The Statistics screen renders three per-mode cards (Single Player,
--   Two Player Local, Two Player Online) from UserStats.spGames / localMpGames /
--   onlineGames. Those fields were read from JSON but the columns never existed
--   on public.user_stats, so they always parsed as 0. Every user saw
--   "0 games - 0% win rate" on all three cards no matter how much they played.
--
-- FIX
--   Add the columns and start maintaining them from _updateUserStats().
--
--   Columns that existed only in the Dart model and had no backing column are
--   NOT added here, because nothing writes them either:
--     sp_best_time, sp_best_moves, online_rating
--   They are left out of the UI by the accompanying client change rather than
--   being added as columns that would always be 0 — which is the same bug this
--   migration fixes.
--
--   Existing rows stay at 0: per-mode history cannot be reconstructed reliably
--   from the games table alone (pre-existing games rows exist but were written
--   with varying game_mode values), so counters start fresh from the next game.
--
--   ROLLBACK
--   Safe: drop the added columns. Nothing else references them.
-- ============================================================================

alter table public.user_stats
  add column if not exists sp_games      integer not null default 0,
  add column if not exists sp_wins       integer not null default 0,
  add column if not exists local_mp_games integer not null default 0,
  add column if not exists local_mp_wins  integer not null default 0,
  add column if not exists online_games  integer not null default 0,
  add column if not exists online_wins   integer not null default 0;
