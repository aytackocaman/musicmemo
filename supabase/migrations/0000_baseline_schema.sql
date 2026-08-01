-- ============================================================================
-- Music Memo — Full schema baseline
-- Generated 2026-08-01 from the live Supabase project (ref: udzcfzykqjkkccwgdahb)
-- via read-only information_schema / pg_catalog queries.
--
-- PURPOSE: disaster recovery. If the project is lost or you need a fresh
-- dev/staging environment, run this file top-to-bottom on a new Supabase
-- project (SQL Editor or `supabase db push`). It recreates:
--   extensions, 13 tables, constraints, indexes, functions, triggers,
--   RLS policies, the storage bucket, and the pg_cron cleanup jobs.
--
-- NOTES
--   * Supabase applies default privileges to anon/authenticated roles
--     automatically — no explicit GRANT statements are needed.
--   * pg_cron / supabase_vault / pg_stat_statements must be enabled via
--     Dashboard → Database → Extensions (they cannot be created from SQL
--     in some plans); the statements below are idempotent IF NOT EXISTS.
--   * Run the pg_cron job inserts only once (they'd duplicate otherwise).
-- ============================================================================

-- ─── Extensions ─────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS plpgsql;

-- The following are managed via the Supabase dashboard:
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
--   CREATE EXTENSION IF NOT EXISTS supabase_vault;
--   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ─── Tables (dependency order) ──────────────────────────────────────────────

-- Category groups (top-level collections: "Feel", "Instruments", ...)
CREATE TABLE public.category_groups (
    id text PRIMARY KEY,
    name text NOT NULL,
    icon text,
    sort_order integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    group_type text NOT NULL DEFAULT 'collection'::text
);

-- Sound categories (49+ playable categories)
CREATE TABLE public.sound_categories (
    id text PRIMARY KEY,
    group_id text NOT NULL REFERENCES public.category_groups(id) ON DELETE CASCADE,
    name text NOT NULL,
    icon text,
    sound_count integer DEFAULT 0,
    is_premium boolean DEFAULT false,
    sort_order integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    pixabay_slug text,
    show_in_ui boolean NOT NULL DEFAULT true,
    sub_group text
);

-- Individual sounds (one row per playable audio clip)
CREATE TABLE public.sounds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id text NOT NULL REFERENCES public.sound_categories(id) ON DELETE CASCADE,
    name text NOT NULL,
    file_path text NOT NULL,
    duration_ms integer DEFAULT 2000,
    file_size_bytes integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    pixabay_id text,
    author text,
    CONSTRAINT sounds_pixabay_id_category_id_key UNIQUE (pixabay_id, category_id)
);

-- Sound tags (tag:type:value rows per sound)
CREATE TABLE public.sound_tags (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sound_id uuid NOT NULL REFERENCES public.sounds(id) ON DELETE CASCADE,
    tag_type text NOT NULL,
    tag_value text NOT NULL,
    CONSTRAINT sound_tags_sound_id_tag_type_tag_value_key UNIQUE (sound_id, tag_type, tag_value)
);

-- Tag value dictionary (available filters with counts)
CREATE TABLE public.tag_values (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_type text NOT NULL,
    value text NOT NULL,
    sound_count integer NOT NULL DEFAULT 0,
    is_premium boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    CONSTRAINT tag_values_tag_type_value_key UNIQUE (tag_type, value)
);

-- User profiles (extends auth.users)
CREATE TABLE public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name text,
    avatar_url text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Subscriptions (cache of premium state; RevenueCat is source of truth)
CREATE TABLE public.subscriptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    plan text NOT NULL DEFAULT 'free'::text,
    status text NOT NULL DEFAULT 'active'::text,
    started_at timestamptz DEFAULT now(),
    expires_at timestamptz,
    store_product_id text,
    store_transaction_id text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT subscriptions_user_id_key UNIQUE (user_id)
);

-- Aggregate user statistics
CREATE TABLE public.user_stats (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    total_games integer DEFAULT 0,
    total_wins integer DEFAULT 0,
    total_score integer DEFAULT 0,
    high_score integer DEFAULT 0,
    current_streak integer DEFAULT 0,
    best_streak integer DEFAULT 0,
    favorite_category text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT user_stats_user_id_key UNIQUE (user_id)
);

-- Per-category statistics
CREATE TABLE public.category_stats (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    category text NOT NULL,
    plays integer DEFAULT 0,
    wins integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT category_stats_user_id_category_key UNIQUE (user_id, category)
);

-- Daily free-tier game counters
CREATE TABLE public.daily_game_counts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    date date NOT NULL DEFAULT CURRENT_DATE,
    single_player_count integer DEFAULT 0,
    local_multiplayer_count integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT daily_game_counts_user_id_date_key UNIQUE (user_id, date)
);

-- Game history
CREATE TABLE public.games (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    category text NOT NULL,
    score integer NOT NULL,
    moves integer NOT NULL,
    time_seconds integer NOT NULL,
    won boolean NOT NULL,
    grid_size text NOT NULL,
    played_at timestamptz DEFAULT now(),
    game_mode text DEFAULT 'single_player'::text
);

-- Online multiplayer sessions
CREATE TABLE public.online_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    player1_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    player2_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    player1_name text,
    player2_name text,
    player1_score integer DEFAULT 0,
    player2_score integer DEFAULT 0,
    category text NOT NULL,
    grid_size text NOT NULL,
    status text NOT NULL DEFAULT 'waiting'::text,
    current_turn uuid,
    game_state jsonb,
    invite_code text,
    winner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    started_at timestamptz,
    finished_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    is_public boolean NOT NULL DEFAULT false,
    rematch_player1 boolean NOT NULL DEFAULT false,
    rematch_player2 boolean NOT NULL DEFAULT false,
    player1_left boolean NOT NULL DEFAULT false,
    player2_left boolean NOT NULL DEFAULT false,
    CONSTRAINT online_sessions_invite_code_key UNIQUE (invite_code)
);

-- Daily challenge leaderboard
CREATE TABLE public.daily_challenge_scores (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date date NOT NULL,
    score integer NOT NULL,
    moves integer NOT NULL,
    time_seconds integer NOT NULL,
    category text NOT NULL,
    grid_size text NOT NULL,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT daily_challenge_scores_user_id_date_key UNIQUE (user_id, date)
);

-- ─── Custom indexes (constraint-backed indexes come from the DDL above) ─────

CREATE INDEX idx_daily_challenge_date_score ON public.daily_challenge_scores USING btree (date, score DESC);
CREATE INDEX idx_daily_game_counts_user_date ON public.daily_game_counts USING btree (user_id, date);
CREATE INDEX idx_games_game_mode ON public.games USING btree (game_mode);
CREATE INDEX idx_games_user_id ON public.games USING btree (user_id);
CREATE INDEX idx_online_sessions_invite_code ON public.online_sessions USING btree (invite_code);
CREATE INDEX idx_online_sessions_player1 ON public.online_sessions USING btree (player1_id);
CREATE INDEX idx_online_sessions_player2 ON public.online_sessions USING btree (player2_id);
CREATE INDEX idx_online_sessions_status ON public.online_sessions USING btree (status);
CREATE INDEX sound_tags_lookup_idx ON public.sound_tags USING btree (tag_type, tag_value);
CREATE INDEX sound_tags_sound_idx ON public.sound_tags USING btree (sound_id);

-- ─── Functions ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Create profile
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  );

  -- Create user stats
  INSERT INTO public.user_stats (user_id)
  VALUES (NEW.id);

  -- Create 7-day trial subscription
  INSERT INTO public.subscriptions (user_id, plan, status, expires_at)
  VALUES (NEW.id, 'trial', 'active', NOW() + INTERVAL '7 days');

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_play_game(p_user_id uuid, p_game_mode text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_plan TEXT;
  v_count INTEGER;
  v_limit INTEGER;
BEGIN
  -- Get user's subscription plan
  SELECT plan INTO v_plan FROM subscriptions WHERE user_id = p_user_id;

  -- Premium users have no limits
  IF v_plan IN ('monthly', 'yearly') THEN
    RETURN TRUE;
  END IF;

  -- Online multiplayer always requires premium
  IF p_game_mode = 'online_multiplayer' THEN
    RETURN FALSE;
  END IF;

  -- Get today's count for the game mode
  SELECT
    CASE p_game_mode
      WHEN 'single_player' THEN COALESCE(single_player_count, 0)
      WHEN 'local_multiplayer' THEN COALESCE(local_multiplayer_count, 0)
      ELSE 0
    END INTO v_count
  FROM daily_game_counts
  WHERE user_id = p_user_id AND date = CURRENT_DATE;

  -- If no record exists, count is 0
  IF v_count IS NULL THEN
    v_count := 0;
  END IF;

  -- Set limits: 5 for single player, 3 for local multiplayer
  v_limit := CASE p_game_mode
    WHEN 'single_player' THEN 5
    WHEN 'local_multiplayer' THEN 3
    ELSE 0
  END;

  RETURN v_count < v_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.increment_game_count(p_user_id uuid, p_game_mode text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO daily_game_counts (user_id, date, single_player_count, local_multiplayer_count)
  VALUES (
    p_user_id,
    CURRENT_DATE,
    CASE WHEN p_game_mode = 'single_player' THEN 1 ELSE 0 END,
    CASE WHEN p_game_mode = 'local_multiplayer' THEN 1 ELSE 0 END
  )
  ON CONFLICT (user_id, date) DO UPDATE SET
    single_player_count = daily_game_counts.single_player_count +
      CASE WHEN p_game_mode = 'single_player' THEN 1 ELSE 0 END,
    local_multiplayer_count = daily_game_counts.local_multiplayer_count +
      CASE WHEN p_game_mode = 'local_multiplayer' THEN 1 ELSE 0 END;
END;
$function$;

-- ─── Trigger ────────────────────────────────────────────────────────────────

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── Row Level Security ─────────────────────────────────────────────────────

ALTER TABLE public.category_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.category_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenge_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_game_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sound_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sound_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tag_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stats ENABLE ROW LEVEL SECURITY;

-- category_groups
CREATE POLICY "Anyone can read category groups" ON public.category_groups
  FOR SELECT USING (true);

-- category_stats
CREATE POLICY "Users can view own category stats" ON public.category_stats
  FOR ALL USING (auth.uid() = user_id);

-- daily_challenge_scores
CREATE POLICY "Anyone can view daily scores" ON public.daily_challenge_scores
  FOR SELECT USING (true);
CREATE POLICY "Users can insert own daily score" ON public.daily_challenge_scores
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- daily_game_counts
CREATE POLICY "Users can insert own daily counts" ON public.daily_game_counts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own daily counts" ON public.daily_game_counts
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can view own daily counts" ON public.daily_game_counts
  FOR SELECT USING (auth.uid() = user_id);

-- games
CREATE POLICY "Users can view own games" ON public.games
  FOR ALL USING (auth.uid() = user_id);

-- online_sessions
CREATE POLICY "Hosts can delete waiting sessions" ON public.online_sessions
  FOR DELETE USING ((auth.uid() = player1_id) AND (status = 'waiting'::text));
CREATE POLICY "Players can update own sessions" ON public.online_sessions
  FOR UPDATE USING ((auth.uid() = player1_id) OR (auth.uid() = player2_id));
CREATE POLICY "Players can view own sessions" ON public.online_sessions
  FOR SELECT USING ((auth.uid() = player1_id) OR (auth.uid() = player2_id) OR ((status = 'waiting'::text) AND (player2_id IS NULL)));
CREATE POLICY "Users can create sessions" ON public.online_sessions
  FOR INSERT WITH CHECK (auth.uid() = player1_id);
CREATE POLICY "Users can update own sessions" ON public.online_sessions
  FOR UPDATE USING ((auth.uid() = player1_id) OR (auth.uid() = player2_id) OR ((status = 'waiting'::text) AND (player2_id IS NULL)));
CREATE POLICY "Users can view waiting or own sessions" ON public.online_sessions
  FOR SELECT USING ((status = 'waiting'::text) OR (auth.uid() = player1_id) OR (auth.uid() = player2_id));

-- profiles
CREATE POLICY "Anyone can view profiles" ON public.profiles
  FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- sound_categories
CREATE POLICY "Anyone can read sound categories" ON public.sound_categories
  FOR SELECT USING (true);

-- sound_tags
CREATE POLICY "sound_tags are publicly readable" ON public.sound_tags
  FOR SELECT USING (true);

-- sounds
CREATE POLICY "Anyone can read sounds" ON public.sounds
  FOR SELECT USING (true);
CREATE POLICY "sounds are publicly readable" ON public.sounds
  FOR SELECT USING (true);

-- subscriptions
CREATE POLICY "Users can insert own subscription" ON public.subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own subscription" ON public.subscriptions
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can view own subscription" ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- tag_values
CREATE POLICY "tag_values are publicly readable" ON public.tag_values
  FOR SELECT USING (true);

-- user_stats
CREATE POLICY "Users can view own stats" ON public.user_stats
  FOR ALL USING (auth.uid() = user_id);

-- ─── Storage ────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('sounds', 'sounds', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read access for sounds" ON storage.objects
  FOR SELECT USING (bucket_id = 'sounds'::text);

-- ─── Scheduled cleanup (pg_cron; requires the extension to be enabled) ──────

-- Daily game counts are operational data — safe to delete after 7 days:
SELECT cron.schedule('cleanup-game-counts', '0 4 * * *', $$
  DELETE FROM daily_game_counts
  WHERE date < CURRENT_DATE - INTERVAL '7 days';
$$);

-- Finished online sessions are kept 30 days (waiting/playing kept regardless):
SELECT cron.schedule('cleanup-online-sessions', '0 4 * * *', $$
  DELETE FROM online_sessions
  WHERE status = 'finished'
  AND updated_at < NOW() - INTERVAL '30 days';
$$);
