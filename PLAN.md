# Music Memo - Development Plan

> Last synced with codebase: **2026-08-01** (138 commits, first commit 2026-02-04)
> Detailed notes live in `zz_notes_credentials/` (gitignored): `iap-payment-plan.md`,
> `subscription-audit-2026-05-02.md`, `addiction-mechanics.md`, `flaws.md`,
> `versiyonlama ve update ettirme güncellem.md` (master backlog), `* ...som.ini` (online MP punchlist)

## Current Status

**Completed since last update:**
- [x] Sign in with Apple + Google Sign-In (guest mode removed entirely)
- [x] RevenueCat SDK v9 (`purchases_flutter` + `purchases_ui_flutter`) — init, login/logout linking, entitlement `premium`
- [x] Custom PaywallScreen with real monthly/annual prices from RevenueCat offerings
- [x] Purchase + restore wired (Paywall, Settings, Subscription screens); RC Customer Center
- [x] Daily Challenge mode (deterministic xorshift32 seed, weekday grid rotation, leaderboard, own preload/game/win screens)
- [x] 15s turn timers (fuse border animation) for local MP
- [x] Haptic feedback throughout (HapticService + settings toggle)
- [x] Turkish + English localization (360 keys each)
- [x] Dark theme (forced dark-only; light theme code kept but unused)
- [x] Accent color picker, card timing sliders in Settings
- [x] Deep links: `musicmemo://join?code=` + `https://musicmemo.app/join?code=` (cold + warm start)
- [x] Online quick match (public sessions), share invite links, emoji reactions, rematch flow
- [x] iPad support (responsive layout, landscape lock), app icon (scripts/generate_icon.py)
- [x] Sound caching on native (200MB cap), web URL playback fallback

**Verified working (audit 2026-05-02):** free-tier gating consistent at all entry points, errors fail-closed to "free", `bypassPaywall` is debug-only, daily count incremented before game start, 3 AM local reset.

---

## Phase 5.2: Monetization — Remaining

> Pricing (from `iap-payment-plan.md`): Monthly $4.99 / Yearly $35.99, 7-day free trial both.
> Entitlement: `premium`, Offering: `default`. RC App User ID = Supabase user UUID.

### P0 — Ship blockers (from subscription audit)
- [ ] **Fix `env/production.json`** — keys are malformed: `REVENUECAT_API_KEY_` (trailing underscore) + `REVENUECAT_API_KEY_BACKUP_TEST_KEY`; `main.dart` reads `REVENUECAT_API_KEY`, so **prod builds silently fall back to Supabase-only premium checks**. ← **FIX FIRST (one-line fix)**
- [ ] **Client-side sync: RevenueCat → Supabase** — after purchase/restore/login, write real `plan` + `expires_at` to `subscriptions` table (currently stays `free` forever; paying users locked out if RC unreachable)
- [ ] **Read real plan/expiry from `EntitlementInfo`** — synthetic RC subscription is hardcoded `plan: 'yearly'` with no expiry
- [ ] **Commit DB schema/triggers to repo** — only `daily_challenge_scores.sql` exists in `supabase/migrations/`; core schema (profiles, games, `handle_new_user()`, etc.) lives only in the Supabase dashboard
- [ ] **Surface RC init failures** — invalid API key currently fails silently (treats paying users as free, no log)

### P1 — Post-launch hardening
- [ ] RevenueCat webhook → Supabase Edge Function (`handle-revenuecat-webhook`) — server-side source of truth (client-only validation is spoofable on jailbroken devices)
- [ ] Wire `addCustomerInfoListener` (app is pull-only today)
- [ ] Offline subscription cache (SharedPreferences, ~7-day grace) — premium user on flaky connection currently sees paywall
- [ ] Mid-session expiry check (`isExpired` only computed at read-time)

### P2 — Polish
- [ ] Periodic 30-min subscription refresh
- [ ] "Subscription expired" UX dialog, trial-countdown UI
- [ ] Privacy policy + terms of service (required for IAP release)
- [ ] Sandbox testing per 10-item checklist in `iap-payment-plan.md` (restore, TRY pricing, offline cache…)
- [ ] Apple Small Business Program application (30% → 15% cut)

---

## Phase 6: Polish & Launch — Remaining

### 6.1 Retention Mechanics (from `addiction-mechanics.md`, priority order)
1. [ ] **Daily play streaks** — consecutive-day counter + 7-day reward ("strongest retention hook")
2. [ ] **Star ratings per game (1–3)** + category mastery bars (49 categories → 147 goals) + Perfect Game badge
3. [ ] **In-game match-streak multipliers** (2x, 3x score)
4. [ ] XP + levels (~500 XP/level, unlocks: categories, frames, titles; XP bar on home)
5. [ ] Shareable Daily Challenge result text (Wordle-style)
6. [ ] Speed Round mode (cards shown 3–5s, then match from memory)
7. [ ] Sound hints as currency (earn 1 per 3 games, or purchase)
8. [ ] Unlockable sound packs (start with 8–10 categories, earn the rest)
9. [ ] "Revenge" mechanic (3x XP comeback bonus after 2+ losses to same player)
10. [ ] Weekly tournaments (same category/grid for all, top 10% badges)
11. [ ] "Your Audio Memory" brain-training stats card (every 10 games)

### 6.2 UX / Online MP (from `* ...som.ini` punchlist + backlog)
- [ ] Share-link bugs: inviter shows as "someone"; link bounces app↔browser; back button → black screen; hot reload broken via share link
- [ ] Online turn timer: 60s auto-pass, kick after 2nd 60s, warning popup, brighter turn indicator
- [ ] Find Opponent: fix back-navigation screen, show open rooms list with categories
- [ ] Friend system: add-friend post-game, friend requests (queued popups except in-game), friend management screen, game invites (1 active, 120s expiry)
- [ ] Emoji reactions next to username; share button on game-end screen
- [ ] Online bugs: opponent-left-before-start still shown; dead X/cancel buttons on start screen; raw `tag:theme:...` string visible; "you" instead of name; rematch first-sound error; accept-rematch should blink green
- [ ] UI polish: globe icon background, mode ordering (Online → Single → Local), keyboard dismiss on outside tap, email autofill hints, numeric-only room codes, settings name change not reflected, versus screen centering, win fireworks, Rap category, customizable card backs

### 6.3 Known Flaws (from `flaws.md`)
- [x] ~~`DevConfig.bypassPaywall` security risk~~ — debug-only, safe (audit confirmed)
- [ ] Sound tag integrity — tags stored as JSON string, no validation (Medium)
- [ ] Orphaned `online_sessions` rows on disconnect; `player2_id` not confirmed before join (Medium)
- [ ] Local MP scores not persisted locally (Low)
- [ ] Fragile `tag:type:value` encoding — breaks if value contains colons (Low)
- [ ] Provider invalidation timing — stale data if navigation precedes invalidation (Low)

### 6.4 Code Health (found in 2026-08-01 review)
- [ ] Two parallel online flows: `OnlineLobbyScreen` (old, still linked from `grid_screen.dart`) vs `OnlineModeScreen` (primary) — consolidate
- [ ] Remove leftover `print()` debug logging in `daily_challenge_preload_screen.dart`
- [ ] `providers.dart` barrel missing settings + daily-challenge exports
- [ ] Light theme + `_ThemeSelector` are dead code (app forced dark) — decide: ship light mode or delete
- [ ] Untracked `assets/icon/app_icon_animated_deleted.mp4` — delete or commit
- [ ] No sound/volume setting exists

### 6.5 App Store Preparation
- [ ] App Store screenshots
- [ ] Privacy policy + terms of service
- [ ] One-time onboarding/tutorial for first install (incl. subscription explanation)
- [ ] Force-update mechanism (check version on app open, prompt update)
- [ ] Reset statistics button; connection retry for dropped internet

### 6.6 Testing
- [ ] Unit tests for game logic (`game_utils.dart`, `daily_challenge_service.dart` — pure Dart, easy wins)
- [ ] Widget tests (`test/widget_test.dart` is a stub with `// TODO: Add actual widget tests`)
- [ ] Integration tests for auth flow
- [ ] TestFlight beta testing

---

## Launch Roadmap (agreed 2026-08-01)

The game is feature-complete. The only goal now is **shipping v1.0**. Work in this exact order:

### Phase 1: Ship v1.0 (in order)
1. **Fix `env/production.json` key name** (5 min) — malformed `REVENUECAT_API_KEY_` means prod builds silently ignore RevenueCat; without this, everything below is pointless
2. **Read real plan + expiry from `EntitlementInfo`** (~half day) — fixes flaws.md #1: premium is synthesized as `plan: 'yearly'` with no expiry, so a lapsed subscription never downgrades
3. **Client-side sync RevenueCat → Supabase after purchase/restore/login** (~half day) — closes audit BUG 1: `subscriptions` table stays `free` forever after someone pays
4. **Commit DB schema to `supabase/migrations/`** ✅ Done 2026-08-01 — `0000_baseline_schema.sql` recreates the full live schema (13 tables, indexes, functions, triggers, RLS, storage bucket, cron jobs); validated via rollback test against live DB. Superseded `daily_challenge_scores.sql` + `subscriptions_client_sync_rls.sql` were consolidated into it.
5. **Privacy policy + terms** (few hours, no code) — hard App Store requirement for IAP; host on the `site/` deployment, link from app + listing
6. **Sandbox test the 10-item checklist from `iap-payment-plan.md`, then submit**

Total realistic effort: ~3–4 focused days of coding + Apple review wait.

### Deliberately skip until after launch
- RevenueCat webhook (P1.1) — client sync is enough for launch volume
- All of `addiction-mechanics.md` — retention matters only with users to retain
- Online-MP punchlist (share-link bugs, friend system, online turn timers)
- Migrating Pixabay sounds to AI-generated — Pixabay is fine (see license notes below); use AI generation only for NEW categories later
- Test suite — don't gate shipping on tests; add unit tests for `game_utils` + `daily_challenge_service` after submission
- Force-update, onboarding tutorial, light theme, leaderboards
- Other flaws.md items (tag integrity, orphaned sessions, provider invalidation) — all Medium/Low, post-launch hardening

### Phase 2: First month after launch
1. Crash reporting (Sentry — add the MCP then)
2. RevenueCat webhook once real money flows
3. Daily streaks (best retention ROI per `addiction-mechanics.md`)
4. Online-MP punchlist, driven by actual user feedback

### Sound licensing notes (Pixabay)
Verified safe to ship: Pixabay Content License allows commercial use in apps, no attribution. Keep: sound manifest (URL/ID/date per file), archive.org snapshot of the license page, "Sound effects from Pixabay" credit in Settings → About. Avoid Pixabay *music* clips (YouTube Content ID risk in promo videos). Confirm no Freesound/CC-BY-NC files are mixed in.

---

## Tech Decisions (resolved)

| Decision | Outcome |
|----------|---------|
| State Management | Riverpod ✅ |
| Sound storage | Remote (Supabase Storage) + native disk cache; zero bundled sounds ✅ |
| Subscriptions | RevenueCat (`purchases_flutter` v9) ✅ |
| Online matchmaking | Both invite codes AND public quick match ✅ |
| Guest mode | Removed entirely — email/Google/Apple only ✅ |
| Theme | Dark-only ✅ (light theme kept as dead code) |
| Navigation | Imperative `Navigator.push` + global `navigatorKey` (no named routes) ✅ |

## Notes

- Test on Chrome first for faster iteration
- Designs in `/pencil/design.pen` (has uncommitted changes as of 2026-08-01)
- `zz_notes_credentials/` is gitignored — keep it that way (contains live credential files)
- Run with `--dart-define-from-file=env/development.json` (dev) or `env/production.json` (prod)
