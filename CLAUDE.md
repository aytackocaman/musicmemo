# Music Memo - Project Context

## Working Style
- Explain technical decisions in plain language
- Check in before making architectural choices
- Build incrementally so I can review each step
- Push back if something is overcomplicating the project
- Be honest about limitations and trade-offs
- **Never commit or push automatically. Only commit and push when explicitly asked.**

## Project Overview

A turn-based mobile card matching game where players flip cards to hear sounds and match pairs by memory. Built with Flutter for cross-platform support.

## Target Platforms

- **Primary:** iOS (iPhone)
- **Future:** Android

## Game Concept

- Grid of face-down cards on screen like (7x6 etc.)
- Each card has an associated sound (same sound pair is in another card in the grid)
- Player taps a card to flip it and hear its sound (card flips back after some time if no match)
- Player must find matching sound pairs from the grid
- Successful matches increase score
- Complete all matches or get a score that guarantees winning to win the level

## Game Modes

### Single Player Mode
- Player plays alone against the clock
- Free for first 5 games per day, then requires subscription
- Track personal best scores and times

### Two Player Local Mode
- Two players on the same device, taking turns
- Each player selects a color and enters their name before game starts
- Turn-based: players alternate flipping cards
- Matched pairs count toward the player who found them
- Free for first 3 games per day, then requires subscription

### Two Player Online Mode
- Real-time multiplayer with another user
- **Always requires subscription** (Premium feature)
- Matchmaking or invite friends via code
- Shows both player names and live scores during game
- Turn indicator shows whose turn it is

## Monetization

### Free Tier
- Single Player: 5 free games per day
- Two Player Local: 3 free games per day
- Two Player Online: Not available

### Premium Subscription
- Unlimited Single Player games
- Unlimited Two Player Local games
- Access to Two Player Online mode
- Ad-free experience
- Exclusive sound categories

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter |
| Language | Dart |
| Sound | `audioplayers` package (planned) |
| State Management | Riverpod (flutter_riverpod: ^2.6.1) |
| Local Storage | SharedPreferences |
| Backend | Supabase (Auth + PostgreSQL) |
| Authentication | Email/Password + Google Sign-In + Guest Mode |

## Design System

Designs are created in Pencil (`.pen` files) located in `/pencil/` folder.

### Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| Purple (Primary) | `#8B5CF6` | Primary actions, active states |
| Teal (Success) | `#14B8A6` | Matched cards, positive feedback |
| Pink (Accent) | `#F472B6` | Hints, special elements |
| White | `#FFFFFF` | Background |
| Gray (Surface) | `#F4F4F5` | Card surfaces, secondary buttons |
| Dark Text | `#18181B` | Primary text |
| Muted Text | `#71717A` | Secondary text |

### Typography

- **Headlines:** Plus Jakarta Sans (Bold/ExtraBold)
- **Body:** Inter (Regular/Medium/SemiBold)

### Corner Radius

- Cards: 16px
- Buttons: 24px
- Logo/Icons: 32px

## Screens

### Auth Flow
1. **Splash Screen** - App logo on purple background, loading indicator, checks auth state
2. **Login Screen** - Welcome message, Google Sign-In button, Play as Guest option, Terms/Privacy links

### Main Flow
3. **Home Screen** - Logo, Play/Statistics/Settings buttons
4. **Mode Screen** - Single Player, Two Player Local, Two Player Online options
5. **Category Screen** - Select a category (searchable, 1000+ categories)
6. **Grid Screen** - Grid size selection (4x5, 5x6, 6x7)

### Game Screens
7. **Single Player Game Screen** - Card grid, score/moves/time stats
8. **Local Two Player Setup Screen** - Color picker and name input for Player 1 & Player 2
9. **Local Two Player Game Screen** - Card grid, both player names with colors, scores, turn indicator
10. **Online Game Screen** - Card grid, opponent name/avatar, both scores, turn indicator, connection status
11. **Win Screen** - Trophy, stats summary, star rating, next level/replay/home buttons (adapts for multiplayer)

### Stats & Settings
12. **Statistics Screen** - Overall stats, per-mode breakdown, recent games, achievements
13. **Subscription Screen** - Current plan info, upgrade options, manage subscription
14. **Paywall Screen** - Shown when free games exhausted, subscription benefits, upgrade CTA

### Flow Diagrams

**Auth Flow:**
```
App Start → Splash (check auth) → Login Screen (if not logged in)
                                → Home Screen (if logged in/guest)
```

**Single Player Flow:**
```
Home → Mode (Single Player) → [Paywall if limit reached] → Category → Grid → Game → Win
```

**Two Player Local Flow:**
```
Home → Mode (Local) → [Paywall if limit reached] → Category → Grid → Player Setup → Game → Win
```

**Two Player Online Flow:**
```
Home → Mode (Online) → [Paywall if no subscription] → Matchmaking/Invite → Category → Grid → Game → Win
```

## Card States

| State | Visual | Description |
|-------|--------|-------------|
| Face Down | Purple with music icon (30% opacity) | Not yet flipped |
| Flipped | White with purple border + sound icon | Currently playing sound |
| Matched | Teal with white icon | Successfully matched pair |

## Authentication

### Login Methods
- **Email/Password** - Primary auth method via Supabase Auth
- **Google Sign-In** - Integrated via Supabase Auth
- **Sign in with Apple** - Integrated via Supabase Auth
- **Guest mode was removed** — email/Google/Apple only

### Supabase Data Model (PostgreSQL)

> **Source of truth:** `supabase/migrations/0000_baseline_schema.sql` recreates the
> full live schema (13 tables, indexes, functions, triggers, RLS, storage bucket,
> cron jobs). The summary below is a readable view, not the full DDL.
> Regenerate the baseline from the dashboard when the schema changes.

```sql
-- User profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subscriptions (cache of premium state; RevenueCat is the source of truth,
-- client syncs plan + expires_at after purchase/restore/login)
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free',  -- 'free', 'monthly', 'yearly', 'trial'
  status TEXT NOT NULL DEFAULT 'active',  -- 'active', 'cancelled', 'expired'
  started_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  store_product_id TEXT,  -- App Store/Play Store product ID
  store_transaction_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Daily game counts (for free tier limits)
CREATE TABLE daily_game_counts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  single_player_count INTEGER DEFAULT 0,
  local_multiplayer_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- Aggregate user statistics (no per-mode columns in the live schema)
CREATE TABLE user_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  total_games INTEGER DEFAULT 0,
  total_wins INTEGER DEFAULT 0,
  total_score INTEGER DEFAULT 0,
  high_score INTEGER DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  best_streak INTEGER DEFAULT 0,
  favorite_category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Per-category statistics
CREATE TABLE category_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  plays INTEGER DEFAULT 0,
  wins INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, category)
);

-- Game history (no opponent columns in the live schema)
CREATE TABLE games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  score INTEGER NOT NULL,
  moves INTEGER NOT NULL,
  time_seconds INTEGER NOT NULL,
  won BOOLEAN NOT NULL,
  grid_size TEXT NOT NULL,  -- e.g., "4x5"
  played_at TIMESTAMPTZ DEFAULT NOW(),
  game_mode TEXT DEFAULT 'single_player'  -- 'single_player', 'local_multiplayer', 'online_multiplayer', 'daily_challenge'
);

-- Online game sessions (real-time multiplayer)
CREATE TABLE online_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player1_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  player2_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  player1_name TEXT,
  player2_name TEXT,
  player1_score INTEGER DEFAULT 0,
  player2_score INTEGER DEFAULT 0,
  category TEXT NOT NULL,
  grid_size TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'waiting',  -- 'waiting', 'playing', 'finished'
  current_turn UUID,
  game_state JSONB,
  invite_code TEXT UNIQUE,
  winner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  is_public BOOLEAN NOT NULL DEFAULT false,
  rematch_player1 BOOLEAN NOT NULL DEFAULT false,
  rematch_player2 BOOLEAN NOT NULL DEFAULT false,
  player1_left BOOLEAN NOT NULL DEFAULT false,
  player2_left BOOLEAN NOT NULL DEFAULT false
);

-- Daily challenge leaderboard (deterministic daily puzzle)
CREATE TABLE daily_challenge_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  score INTEGER NOT NULL,
  moves INTEGER NOT NULL,
  time_seconds INTEGER NOT NULL,
  category TEXT NOT NULL,
  grid_size TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- Sound system (category browsing, tags, and audio clips)
CREATE TABLE category_groups (
  id TEXT PRIMARY KEY,             -- top-level collections ("Feel", ...)
  name TEXT NOT NULL,
  icon TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  group_type TEXT NOT NULL DEFAULT 'collection'
);

CREATE TABLE sound_categories (
  id TEXT PRIMARY KEY,             -- category slug
  group_id TEXT NOT NULL REFERENCES category_groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  icon TEXT,
  sound_count INTEGER DEFAULT 0,
  is_premium BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  pixabay_slug TEXT,
  show_in_ui BOOLEAN NOT NULL DEFAULT true,
  sub_group TEXT
);

CREATE TABLE sounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id TEXT NOT NULL REFERENCES sound_categories(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  file_path TEXT NOT NULL,         -- path in the 'sounds' storage bucket
  duration_ms INTEGER DEFAULT 2000,
  file_size_bytes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  pixabay_id TEXT,
  author TEXT,
  UNIQUE(pixabay_id, category_id)
);

CREATE TABLE sound_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sound_id UUID NOT NULL REFERENCES sounds(id) ON DELETE CASCADE,
  tag_type TEXT NOT NULL,
  tag_value TEXT NOT NULL,
  UNIQUE(sound_id, tag_type, tag_value)
);

CREATE TABLE tag_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_type TEXT NOT NULL,
  value TEXT NOT NULL,
  sound_count INTEGER NOT NULL DEFAULT 0,
  is_premium BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE(tag_type, value)
);

-- Functions (SECURITY DEFINER) + trigger
-- handle_new_user(): on auth.users insert → creates profile + user_stats +
--   a 7-day 'trial' subscription
-- can_play_game(user_id, game_mode): free-tier check (hardcoded 5 SP / 3 LMP,
--   premium = monthly/yearly; NOTE: ignores 'trial' — Dart-side check is authoritative)
-- increment_game_count(user_id, game_mode): upserts today's counters
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Row Level Security (RLS): enabled on ALL 13 tables.
-- Sound/category/tag tables + daily_challenge_scores SELECT: public.
-- User-owned tables (profiles, subscriptions, daily_game_counts, user_stats,
-- category_stats, games): restricted to auth.uid() = own row.
-- online_sessions: participants can view/update own sessions; waiting sessions
-- with no player2 are visible (matchmaking); hosts can delete waiting sessions.
-- storage.objects: "Public read access for sounds" policy (bucket_id = 'sounds').
```

### Storage
- Bucket `sounds` (public, no size/mime limits) — served audio clips; metadata in `sounds` table.

### Supabase Packages
```yaml
supabase_flutter: ^2.8.0
google_sign_in: ^6.2.2
```

### Supabase Setup
1. Create project at [supabase.com](https://supabase.com)
2. Enable Google Auth in Authentication > Providers
3. Run SQL migrations above in SQL Editor
4. Get project URL and anon key from Settings > API
5. Configure Google OAuth credentials

### Making a User Premium (Manual)
Run in SQL Editor. Find the user UUID in Dashboard → Authentication → Users (or query `auth.users`).

```sql
-- Update existing subscription row
UPDATE subscriptions
SET plan = 'monthly',   -- or 'yearly'
    status = 'active',
    expires_at = NOW() + INTERVAL '1 month'  -- or '1 year' for yearly
WHERE user_id = '<user-uuid>';

-- If no row exists yet, insert one
INSERT INTO subscriptions (user_id, plan, status, expires_at)
VALUES ('<user-uuid>', 'monthly', 'active', NOW() + INTERVAL '1 month');
```

Valid plan values: `'free'`, `'trial'`, `'monthly'`, `'yearly'` (must match exactly — app treats `monthly`/`yearly`/`trial` as premium via `UserSubscription.isPremium`, subject to `expires_at`).

### Database Maintenance — Cron Jobs
Enable the `pg_cron` extension first: Dashboard → Database → Extensions → enable `pg_cron`.

**`daily_game_counts`** — safe to delete after 7 days, pure operational data:
```sql
SELECT cron.schedule('cleanup-game-counts', '0 4 * * *', $$
  DELETE FROM daily_game_counts
  WHERE date < CURRENT_DATE - INTERVAL '7 days';
$$);
```

**`online_sessions`** — delete finished sessions after 30 days (keep waiting/playing regardless):
```sql
SELECT cron.schedule('cleanup-online-sessions', '0 4 * * *', $$
  DELETE FROM online_sessions
  WHERE status = 'finished'
  AND updated_at < NOW() - INTERVAL '30 days';
$$);
```

**`games`** — do NOT delete. This is user game history used for stats/leaderboards. Keep indefinitely. Row count is manageable (one row per game played).

Verify jobs: `SELECT * FROM cron.job;`
Remove a job: `SELECT cron.unschedule('job-name');`

### Daily Game Count Reset
Resets happen automatically at **3 AM in each user's local time** — no cron job needed.
`getGameDay()` in `database_service.dart` uses device local time: if `hour < 3` it returns yesterday's date, so the DB row for "today" doesn't exist yet and counts return zero.

## Game Logic (Implementation Status)

- [x] Card flip animation (3D transform with AnimationController)
- [x] Sound playback on flip
- [x] Match detection (compare sound IDs)
- [x] Score calculation (single player + multiplayer)
- [x] Timer
- [x] Move counter
- [x] Grid size selection (4x5, 5x6, 6x7)
- [x] Win condition detection
- [x] Local multiplayer turn management
- [ ] Local high score storage

## File Structure (Planned)

```
lib/
├── main.dart
├── config/
│   ├── theme.dart          # Colors, typography
│   └── constants.dart      # Spacing, sizing, free tier limits
├── models/
│   ├── card.dart           # Card model
│   ├── user.dart           # User model
│   ├── player.dart         # Player model (for multiplayer)
│   ├── game_state.dart     # Game state model
│   ├── user_stats.dart     # User statistics model
│   └── subscription.dart   # Subscription model
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── mode_screen.dart
│   ├── category_screen.dart
│   ├── grid_screen.dart
│   ├── game/
│   │   ├── single_player_game_screen.dart
│   │   ├── local_player_setup_screen.dart
│   │   ├── local_multiplayer_game_screen.dart
│   │   ├── online_game_screen.dart
│   │   └── win_screen.dart
│   ├── statistics_screen.dart
│   ├── subscription_screen.dart
│   └── paywall_screen.dart
├── widgets/
│   ├── game_card.dart      # Flippable card widget
│   ├── stats_row.dart      # Score/Moves/Time display
│   ├── player_score_card.dart  # Player name + score (multiplayer)
│   ├── turn_indicator.dart # Whose turn indicator
│   ├── color_picker.dart   # Color selection for local MP
│   └── game_button.dart    # Reusable button
├── services/
│   ├── supabase_service.dart
│   ├── auth_service.dart
│   ├── database_service.dart
│   ├── audio_service.dart
│   ├── storage_service.dart
│   ├── subscription_service.dart  # IAP + subscription logic
│   └── multiplayer_service.dart   # Online game realtime logic
└── utils/
    ├── sound_matcher.dart
    └── game_limits.dart    # Free tier game counting
```

## Commands

```bash
# Run on Chrome (web) — development (lower free tier limits for testing)
flutter run -d chrome --dart-define-from-file=env/development.json

# Run on iOS Simulator — development
flutter run -d ios --dart-define-from-file=env/development.json

# Run on Chrome (web) — production limits
flutter run -d chrome --dart-define-from-file=env/production.json

# Build for iOS — production
flutter build ios --dart-define-from-file=env/production.json
```

## Notes for Claude

- Pencil designs are in `/pencil/design.pen` - use MCP tools to read
- Start simple: get basic card flip + sound working before adding features
- Test on Chrome first (faster iteration), then iOS
- Keep game logic separate from UI (easier to test)
