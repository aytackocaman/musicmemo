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

### 2.1 State Management ✅
- [x] Add Riverpod dependency (flutter_riverpod: ^2.6.1)
- [x] Set up providers for:
  - Auth state (authProvider, isAuthenticatedProvider, isGuestProvider)
  - User profile (userProfileProvider, userProfileNotifierProvider)
  - Game state (gameProvider, selectedGameModeProvider, playerSetupProvider)
  - Subscription status (subscriptionProvider, isPremiumProvider)
  - Daily limits (dailyGameCountsProvider, canPlayGameModeProvider)

### 2.2 Navigation
- [x] Implement navigation flow between screens (Home → Mode → Category → Grid)
- [ ] Add route guards (auth required, subscription required)
- [ ] Handle deep linking

### 2.3 Remaining Screens (from Pencil designs)
- [x] Mode Selection Screen
- [x] Category Selection Screen (with search)
- [x] Grid Size Selection Screen
- [x] Player Setup Screen (local multiplayer)
- [x] Statistics Screen
- [ ] Subscription Screen
- [ ] Paywall Screen

---

## Phase 3: Game Core

### 3.1 Card System ✅
- [x] Create Card model (id, soundId, state) - in game_provider.dart
- [x] Build GameCard widget with flip animation
- [x] Implement card states (face down, flipped, matched)
- [x] Add card grid layout (responsive to grid size)

### 3.2 Sound System (Deferred)
> **Note:** Sound system will be added after all game modes are working

- [ ] Set up audioplayers package
- [ ] Create AudioService for sound playback
- [ ] Add sound asset management
- [ ] Implement sound preloading
- [ ] Handle sound categories

### 3.3 Game Logic ✅
- [x] Card shuffle algorithm (game_utils.dart)
- [x] Match detection (compare sound IDs)
- [x] Turn management
- [x] Score calculation
- [x] Move counter
- [x] Timer implementation
- [x] Win condition detection

### 3.4 Single Player Game Screen ✅
- [x] Implement game board
- [x] Add stats display (score, moves, time)
- [x] Handle game completion
- [x] Show Win Screen with results

---

## Phase 4: Multiplayer

### 4.1 Local Two-Player Mode ✅
- [x] Player setup screen (names, colors)
- [x] Turn indicator with "YOUR TURN" badge
- [x] Dual score tracking (pairs per player)
- [x] Turn switching logic (switch on no-match, keep turn on match)
- [x] Winner determination (or tie)
- [x] Multiplayer win screen

### 4.2 Online Multiplayer ✅
- [x] Supabase Realtime setup
- [x] Online session management (create/join with invite codes)
- [x] Invite code matchmaking (6-character codes)
- [x] Real-time game state sync (with polling fallback)
- [x] Connection status handling (LIVE indicator)
- [x] Turn-based gameplay over network
- [x] Race condition fixes (turn change detection, card state sync)
- [x] Rapid click prevention (all game modes)
- [ ] Reconnection logic (future improvement)
- [ ] Opponent disconnect handling (future improvement)

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
- [x] Save game history to Supabase (single player win screen)
- [x] Calculate and display statistics (Statistics Screen)
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
3. ~~**Add Riverpod**~~ ✅ Done
4. ~~**Build navigation screens**~~ ✅ Done (Mode, Category, Grid screens)
5. ~~**Implement Card widget**~~ ✅ Done (GameCard with flip animation)
6. ~~**Single player game**~~ ✅ Done (Game screen + Win screen)
7. ~~**Local multiplayer**~~ ✅ Done (Player setup + turn-based game + win screen)
8. ~~**Online multiplayer**~~ ✅ Done (Supabase Realtime + invite codes + race condition fixes)
9. ~~**Statistics screen**~~ ✅ Done (Overall stats, per-mode breakdown, game saving)
10. **Free tier limits** - Implement daily game counting + paywall ← **START HERE**
11. **Add sound system** - Integrate audioplayers package
12. **Subscription system** - RevenueCat integration

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
