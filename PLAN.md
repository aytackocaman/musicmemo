# Music Memo - Development Plan

## Current Status

**Completed:**
- [x] Flutter project setup with cross-platform support
- [x] Supabase integration with secure env-based credentials
- [x] Basic screens: Splash, Login, Home
- [x] Theme configuration (colors, typography)
- [x] Project documentation (CLAUDE.md)
- [x] UI/UX designs for all 14 screens (Pencil)

---

## Phase 1: Database & Authentication

### 1.1 Supabase Database Setup ✅
- [x] Run SQL migrations to create tables:
  - `profiles` (user profiles)
  - `user_stats` (game statistics)
  - `category_stats` (per-category stats)
  - `games` (game history + game_mode column)
  - `subscriptions` (premium status)
  - `daily_game_counts` (free tier tracking)
  - `online_sessions` (multiplayer games)
- [x] Configure Row Level Security (RLS) policies
- [x] Create helper functions:
  - `handle_new_user()` - auto-creates profile, stats, subscription on signup
  - `can_play_game()` - checks free tier limits
  - `increment_game_count()` - tracks daily plays
- [x] Fix security warnings (function search paths)

### 1.2 Authentication ✅
- [x] Implement email/password sign up
- [x] Implement email/password sign in
- [x] Add password reset flow
- [x] Implement guest mode (anonymous auth)
- [x] Handle auth state persistence (via Supabase)
- [x] Add "link account" for guest users
- [ ] Add Google Sign-In integration (future)

**Note:** Enable "Allow anonymous sign-ins" in Supabase Dashboard → Authentication → Providers

---

## Phase 2: Core App Structure

### 2.1 State Management
- [ ] Add Riverpod dependency
- [ ] Set up providers for:
  - Auth state
  - User profile
  - Game state
  - Subscription status

### 2.2 Navigation
- [ ] Implement navigation flow between screens
- [ ] Add route guards (auth required, subscription required)
- [ ] Handle deep linking

### 2.3 Remaining Screens (from Pencil designs)
- [ ] Mode Selection Screen
- [ ] Category Selection Screen (with search)
- [ ] Grid Size Selection Screen
- [ ] Player Setup Screen (local multiplayer)
- [ ] Statistics Screen
- [ ] Subscription Screen
- [ ] Paywall Screen

---

## Phase 3: Game Core

### 3.1 Card System
- [ ] Create Card model (id, soundId, state)
- [ ] Build GameCard widget with flip animation
- [ ] Implement card states (face down, flipped, matched)
- [ ] Add card grid layout (responsive to grid size)

### 3.2 Sound System
- [ ] Set up audioplayers package
- [ ] Create AudioService for sound playback
- [ ] Add sound asset management
- [ ] Implement sound preloading
- [ ] Handle sound categories

### 3.3 Game Logic
- [ ] Card shuffle algorithm
- [ ] Match detection (compare sound IDs)
- [ ] Turn management
- [ ] Score calculation
- [ ] Move counter
- [ ] Timer implementation
- [ ] Win condition detection

### 3.4 Single Player Game Screen
- [ ] Implement game board
- [ ] Add stats display (score, moves, time)
- [ ] Handle game completion
- [ ] Show Win Screen with results

---

## Phase 4: Multiplayer

### 4.1 Local Two-Player Mode
- [ ] Player setup (names, colors)
- [ ] Turn indicator
- [ ] Dual score tracking
- [ ] Turn switching logic
- [ ] Winner determination

### 4.2 Online Multiplayer
- [ ] Supabase Realtime setup
- [ ] Online session management
- [ ] Matchmaking system
- [ ] Real-time game state sync
- [ ] Connection status handling
- [ ] Reconnection logic
- [ ] Opponent disconnect handling

---

## Phase 5: Monetization

### 5.1 Free Tier Limits
- [ ] Track daily game counts per mode
- [ ] Check limits before game start
- [ ] Show paywall when limit reached
- [ ] Reset counts daily (server-side)

### 5.2 Subscription System
- [ ] Integrate RevenueCat or in-app purchases
- [ ] Handle subscription status
- [ ] Sync with Supabase
- [ ] Restore purchases
- [ ] Premium feature unlocking

---

## Phase 6: Polish & Launch

### 6.1 Data & Progress
- [ ] Save game history to Supabase
- [ ] Calculate and display statistics
- [ ] Implement leaderboards (optional)

### 6.2 UX Improvements
- [ ] Add haptic feedback
- [ ] Loading states and skeletons
- [ ] Error handling and retry logic
- [ ] Offline mode support

### 6.3 App Store Preparation
- [ ] App icons (all sizes)
- [ ] Splash screen assets
- [ ] App Store screenshots
- [ ] Privacy policy
- [ ] Terms of service

### 6.4 Testing
- [ ] Unit tests for game logic
- [ ] Widget tests for UI components
- [ ] Integration tests for auth flow
- [ ] Beta testing

---

## Recommended Next Steps

Start with these tasks in order:

1. ~~**Run Supabase migrations**~~ ✅ Done
2. ~~**Complete auth flow**~~ ✅ Done
3. **Add Riverpod** - State management foundation ← **START HERE**
4. **Build Category Screen** - Need content before games
5. **Implement Card widget** - Core game component
6. **Add sound system** - Essential for gameplay
7. **Single player game** - First playable version

---

## Tech Decisions Needed

| Decision | Options | Recommendation |
|----------|---------|----------------|
| State Management | Riverpod, Bloc, Provider | Riverpod |
| Sound Categories | Bundled assets, Remote CDN | Start bundled, add remote later |
| Subscriptions | RevenueCat, Direct IAP | RevenueCat (easier) |
| Online Matchmaking | Random, Invite code, Both | Start with invite codes |

---

## Notes

- Test on Chrome first for faster iteration
- Keep game logic separate from UI
- Designs are in `/pencil/design.pen`
- Environment variables in `.env` (not committed)
